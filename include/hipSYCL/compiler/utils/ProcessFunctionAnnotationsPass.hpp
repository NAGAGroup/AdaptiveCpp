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

#ifndef ACPP_PROCESS_FUNCTION_ANNOTATION_PASS_HPP
#define ACPP_PROCESS_FUNCTION_ANNOTATION_PASS_HPP


#include <llvm/ADT/SmallPtrSet.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IR/Instructions.h>

#include <string>
#include <vector>

#include "hipSYCL/compiler/utils/LLVMUtils.hpp"

namespace hipsycl {
namespace compiler {
namespace utils {

// True iff `Name` is the function `Builtin` itself, not merely a name that contains it.
// Substring matching was wrong: __acpp_function_annotation_dynamic_function is a prefix of
// __acpp_function_annotation_dynamic_function_def_arg0 and _arg1, so the constructor of a
// dynamic_function_definition was classified as a dynamic_function constructor.
// The builtin can appear as:
//  - its plain C name (extern "C" builtins);
//  - an Itanium-mangled identifier, length-prefixed (_Z...<len><name>..., which also covers
//    templated builtins such as argument_used);
//  - an MSVC-mangled name (?name@... or ??$name@... for templates).
inline bool isAnnotationBuiltin(llvm::StringRef Name, llvm::StringRef Builtin) {
  if (Name == Builtin)
    return true;
  if (llvmutils::starts_with(Name, "_Z")) {
    std::string Needle = std::to_string(Builtin.size()) + Builtin.str();
    return Name.contains(Needle);
  }
  if (llvmutils::starts_with(Name, "?")) {
    std::string Plain = "?" + Builtin.str() + "@";
    std::string Templ = "??$" + Builtin.str() + "@";
    return Name.contains(Plain) || Name.contains(Templ);
  }
  return false;
}

class ProcessFunctionAnnotationPass : public llvm::PassInfoMixin<ProcessFunctionAnnotationPass> {
public:
  
  ProcessFunctionAnnotationPass(const std::vector<std::string>& AnnotationsToProcess)
  : AnnotationsToProcess{AnnotationsToProcess} {}

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM) {
    for(const auto& Annotation : AnnotationsToProcess) {
      std::string BuiltinName = "__acpp_function_annotation_"+Annotation;
      processAnnotation(M, Annotation, BuiltinName);
    }
    return llvm::PreservedAnalyses::none();
  }

  const auto& getFoundAnnotations() const {
    return FoundAnnotations;
  }
private:
  void processAnnotation(llvm::Module &M, const std::string &Annotation,
                         const std::string &BuiltinName) {
    
    llvm::SmallVector<llvm::CallBase*> CallsToErase;
    llvm::SmallVector<llvm::Function*> FunctionsToErase;

    for (auto &F : M) {
      if (isAnnotationBuiltin(F.getName(), BuiltinName)) {
        for (auto *U : F.users()) {
          if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
            if (auto *ParentBB = CB->getParent()) {
              if (auto *ParentF = ParentBB->getParent()) {
                FoundAnnotations[Annotation].insert(ParentF);
                CallsToErase.push_back(CB);
              }
            }
          }
        }
        FunctionsToErase.push_back(&F);
      }
    }

    for (auto *C : CallsToErase)
      C->eraseFromParent();

    for (auto *F : FunctionsToErase) {
      F->replaceAllUsesWith(llvm::UndefValue::get(F->getType()));
      F->eraseFromParent();
    }
  }

  std::vector<std::string> AnnotationsToProcess;
  std::unordered_map<std::string, llvm::SmallPtrSet<llvm::Function*, 16>> FoundAnnotations;
};

}
}
}

#endif
