/*
 * This file is part of AdaptiveCpp, an implementation of SYCL and C++ standard
 * parallelism for CPUs and GPUs.
 *
 * Copyright The AdaptiveCpp Contributors
 *
 * AdaptiveCpp is released under the BSD 2-Clause "Simplified" License.
 * See file LICENSE in the project root for full license details.
 */
// SPDX-License-Identifier: BSD-2-Clause



#include "hipSYCL/compiler/sscp/DynamicFunctionSupport.hpp"
#include "hipSYCL/compiler/utils/FunctionPointerArgument.hpp"
#include "hipSYCL/compiler/utils/ProcessFunctionAnnotationsPass.hpp"

#include <llvm/IR/Comdat.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Metadata.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#if LLVM_VERSION_MAJOR < 16
#include <llvm/ADT/Triple.h>
#else
#include <llvm/TargetParser/Triple.h>
#endif

namespace hipsycl::compiler {

llvm::PreservedAnalyses DynamicFunctionIdentifactionPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &AM) {

  // First identify dynamic function infrastructure, which may need
  // separate handling on host and device.
  llvm::SmallVector<llvm::Function *> DynamicFunctions;
  llvm::SmallVector<llvm::Function *> DynamicFunctionDefinitions;

  const std::string DynamicFunctionAnnotation = "dynamic_function";
  const std::string DynamicFunctionDefinitionAnnotationArg0 = "dynamic_function_def_arg0";
  const std::string DynamicFunctionDefinitionAnnotationArg1 = "dynamic_function_def_arg1";

  utils::ProcessFunctionAnnotationPass PFA({DynamicFunctionAnnotation,
                                            DynamicFunctionDefinitionAnnotationArg0,
                                            DynamicFunctionDefinitionAnnotationArg1});
  PFA.run(M, AM);
  const auto &FoundAnnotations = PFA.getFoundAnnotations();
  auto DFIt = FoundAnnotations.find(DynamicFunctionAnnotation);
  auto DFD0It = FoundAnnotations.find(DynamicFunctionDefinitionAnnotationArg0);
  auto DFD1It = FoundAnnotations.find(DynamicFunctionDefinitionAnnotationArg1);

  auto RetrieveFunctionNames = [&](auto It, std::vector<std::string>& Output, int ArgNo){
    for (auto *F : It->second) {
      if (F) {
        for (auto *U : F->users()) {
          if (llvm::CallBase *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
            if (CB->getNumOperands() >= 1 && ArgNo < CB->arg_size()) {
              llvm::SmallVector<llvm::Function *, 4> Resolved;
              if (utils::resolveFunctionPointerArgument(CB, ArgNo, Resolved)) {
                for (auto *DF : Resolved)
                  Output.push_back(DF->getName().str());
              } else {
                M.getContext().emitError(
                    CB, "Detected a dynamic_function or dynamic_function_definition construction "
                        "where the argument is not "
                        "directly a function; dynamic_function function pointer arguments do "
                        "not support indirection.");
              }
            }
          }
        }
      }
    }
  };

  if (DFIt != FoundAnnotations.end()) {
    RetrieveFunctionNames(DFIt, this->DynamicFunctionNames, 1);
  }

  if (DFD0It != FoundAnnotations.end()) {
    RetrieveFunctionNames(DFD0It, this->DynamicFunctionDefinitionNames, 1);
  }

  if (DFD1It != FoundAnnotations.end()) {
    RetrieveFunctionNames(DFD1It, this->DynamicFunctionDefinitionNames, 2);
  }

  return llvm::PreservedAnalyses::none();
}

llvm::PreservedAnalyses HostSideDynamicFunctionHandlerPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &AM) {
  // Provide dummy definitions to avoid linker issues
  for (const auto &FName : DynamicFunctionNames) {
    if (auto *F = M.getFunction(FName)) {
      if (F->isDeclaration()) {
        llvm::LLVMContext &Ctx = M.getContext();
        llvm::Type *Int8Ty = llvm::Type::getInt8Ty(Ctx);
        auto MakeTag = [&](llvm::GlobalValue::LinkageTypes Linkage) {
          return new llvm::GlobalVariable(M, Int8Ty, /*isConstant=*/false, Linkage,
                                          llvm::ConstantInt::get(Int8Ty, 0),
                                          "__acpp_dynfn_tag." + F->getName());
        };
        // The stand-in body, used on both paths: store to the stand-in's own tag, then return.
        // Each stand-in stores to its own tag so identical-code folding (lld-link /OPT:ICF is on by
        // default without /DEBUG) cannot merge two stand-ins into one address, which would break
        // reflection's address-to-name map.
        auto BuildStandIn = [&](llvm::Function *Dummy, llvm::GlobalVariable *Tag) {
          auto BB = llvm::BasicBlock::Create(Ctx, "entry", Dummy);
          llvm::IRBuilder<> Builder(BB);
          Builder.CreateStore(llvm::ConstantInt::get(Int8Ty, 0), Tag)->setVolatile(true);
          // It seems that LLVM handles functions that only have unreachable inst differently
          // if there address is taken - we can no longer get unique function pointer
          // addresses for those, which breaks reflection. So try to generate a trivial function
          // instead.
          if(Dummy->getReturnType()->isVoidTy())
            Builder.CreateRetVoid();
          else
            Builder.CreateRet(llvm::UndefValue::get(Dummy->getReturnType()));
        };
        if (llvm::Triple{M.getTargetTriple()}.isOSBinFormatCOFF()) {
          // COFF: keep the placeholder a declaration. A stand-in with the placeholder's own name
          // would collide with a real definition in another translation unit, so the stand-in D has
          // its own name and /alternatename makes the placeholder resolve to D only when nothing
          // defines it. D is weak_odr, not linkonce_odr: nothing references D in IR, so with
          // linkonce_odr LLVM dropped it as unused and /alternatename dangled. D and its tag share
          // one COMDAT named after D, so they are kept and folded together across translation units.
          std::string DummyName = "__acpp_dynfn_dummy." + F->getName().str();
          auto *D = llvm::Function::Create(F->getFunctionType(), llvm::GlobalValue::WeakODRLinkage,
                                           DummyName, M);
          D->setCallingConv(F->getCallingConv());
          auto *Tag = MakeTag(llvm::GlobalValue::WeakODRLinkage);
          BuildStandIn(D, Tag);
          llvm::Comdat *C = M.getOrInsertComdat(D->getName());
          D->setComdat(C);
          Tag->setComdat(C);
          std::string Directive = "/alternatename:" + F->getName().str() + "=" + DummyName;
          M.getOrInsertNamedMetadata("llvm.linker.options")
              ->addOperand(llvm::MDNode::get(Ctx, {llvm::MDString::get(Ctx, Directive)}));
        } else {
          // ELF, Mach-O: weak, not linkonce_odr. linkonce_odr promises every definition is
          // equivalent, so the optimizer may bind calls to the stand-in, while a default definition
          // of the function in another translation unit must win. WeakAny is interposable, so it is
          // never inlined, and a strong definition wins at link.
          F->setLinkage(llvm::GlobalValue::WeakAnyLinkage);
          auto *Tag = MakeTag(llvm::GlobalValue::WeakAnyLinkage);
          BuildStandIn(F, Tag);
        }
      }
    }
  }

  return llvm::PreservedAnalyses::none();
}


}
