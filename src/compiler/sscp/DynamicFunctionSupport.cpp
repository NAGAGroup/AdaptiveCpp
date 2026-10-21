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
        auto BuildDummyBody = [&M](llvm::Function *Dummy) {
          auto BB = llvm::BasicBlock::Create(M.getContext(), "entry", Dummy);
          // It seems that LLVM handles functions that only have unreachable inst differently
          // if there address is taken - we can no longer get unique function pointer
          // addresses for those, which breaks reflection. So try to generate a trivial function
          // instead.
          if(Dummy->getReturnType()->isVoidTy())
            llvm::ReturnInst::Create(M.getContext(), BB);
          else
            llvm::ReturnInst::Create(M.getContext(), llvm::UndefValue::get(Dummy->getReturnType()), BB);
        };
        if (llvm::Triple{M.getTargetTriple()}.isOSBinFormatCOFF()) {
          // COFF: a COMDAT dummy named like the placeholder collides with a real definition in another
          // translation unit. The dummy gets its own name and /alternatename makes the placeholder resolve
          // to it only when nothing defines it.
          std::string DummyName = "__acpp_dynfn_dummy." + F->getName().str();
          auto *D = llvm::Function::Create(F->getFunctionType(), llvm::GlobalValue::LinkOnceODRLinkage,
                                           DummyName, M);
          D->setCallingConv(F->getCallingConv());
          BuildDummyBody(D);
          D->setComdat(M.getOrInsertComdat(D->getName()));
          std::string Directive = "/alternatename:" + F->getName().str() + "=" + DummyName;
          M.getOrInsertNamedMetadata("llvm.linker.options")
              ->addOperand(llvm::MDNode::get(M.getContext(), {llvm::MDString::get(M.getContext(), Directive)}));
        } else {
          F->setLinkage(llvm::GlobalValue::LinkOnceODRLinkage);
          BuildDummyBody(F);
        }
      }
    }
  }

  return llvm::PreservedAnalyses::none();
}


}
