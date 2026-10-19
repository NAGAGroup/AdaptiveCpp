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

// Helpers for finding the function that a function-pointer argument refers to,
// looking through functions that merely forward the argument.
//
// On Darwin, clang has no constructor aliases, so the complete-object
// constructor (C1) calls the base-object constructor (C2) and forwards the
// function-pointer parameter; the annotated function's only caller therefore
// passes an Argument rather than a Function. ELF aliases C1 to C2 and is
// unaffected.

#ifndef ACPP_COMPILER_UTILS_FUNCTION_POINTER_ARGUMENT_HPP
#define ACPP_COMPILER_UTILS_FUNCTION_POINTER_ARGUMENT_HPP

#include <llvm/ADT/STLFunctionalExtras.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/IR/Argument.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/GlobalAlias.h>
#include <llvm/IR/InstrTypes.h>
#include <llvm/IR/Instructions.h>

#include <set>
#include <utility>

namespace hipsycl {
namespace compiler {
namespace utils {

namespace detail {

using FunctionArgPair = std::pair<const llvm::Function *, unsigned>;

inline bool resolveFunctionPointerArgumentImpl(
    llvm::CallBase *CB, unsigned ArgNo,
    llvm::SmallVectorImpl<llvm::Function *> &Out, unsigned MaxDepth,
    std::set<FunctionArgPair> &Visited) {
  if (!CB || ArgNo >= CB->arg_size())
    return false;

  llvm::Value *V = CB->getArgOperand(ArgNo)->stripPointerCasts();

  if (auto *F = llvm::dyn_cast<llvm::Function>(V)) {
    Out.push_back(F);
    return true;
  }

  if (auto *A = llvm::dyn_cast<llvm::Argument>(V)) {
    if (MaxDepth == 0)
      return false;

    llvm::Function *P = A->getParent();
    if (!P)
      return false;

    // Already followed this (function, argument) pair: nothing new to add.
    if (!Visited.insert({P, A->getArgNo()}).second)
      return true;

    for (llvm::Use &U : P->uses()) {
      llvm::User *Usr = U.getUser();
      if (llvm::isa<llvm::GlobalAlias>(Usr))
        continue;

      auto *CB2 = llvm::dyn_cast<llvm::CallBase>(Usr);
      if (!CB2 || !CB2->isCallee(&U) || CB2->getCalledFunction() != P)
        return false;

      if (!resolveFunctionPointerArgumentImpl(CB2, A->getArgNo(), Out,
                                              MaxDepth - 1, Visited))
        return false;
    }
    // Zero call sites is fine.
    return true;
  }

  return false;
}

inline bool forwardsArgumentToAnnotatedImpl(
    llvm::Function *G, unsigned ArgNo,
    llvm::function_ref<bool(llvm::Function *)> IsAnnotated, unsigned MaxDepth,
    std::set<FunctionArgPair> &Visited) {
  if (!G || G->isDeclaration() || ArgNo >= G->arg_size())
    return false;

  // Already examined this (function, argument) pair.
  if (!Visited.insert({G, ArgNo}).second)
    return false;

  llvm::Argument *Arg = G->getArg(ArgNo);

  for (llvm::User *U : Arg->users()) {
    auto *CB2 = llvm::dyn_cast<llvm::CallBase>(U);
    if (!CB2)
      continue;
    llvm::Function *H = CB2->getCalledFunction();
    if (!H)
      continue;

    for (unsigned j = 0; j < CB2->arg_size(); ++j) {
      if (CB2->getArgOperand(j)->stripPointerCasts() != Arg)
        continue;

      if (IsAnnotated(H))
        return true;
      if (MaxDepth > 0 &&
          forwardsArgumentToAnnotatedImpl(H, j, IsAnnotated, MaxDepth - 1,
                                          Visited))
        return true;
    }
  }
  return false;
}

} // namespace detail

/// Collects the function(s) that argument ArgNo of the call CB refers to. If
/// the argument is a forwarded parameter of the calling function, the call
/// sites of that function are followed, up to MaxDepth levels.
/// Returns false if the argument cannot be resolved to functions.
inline bool
resolveFunctionPointerArgument(llvm::CallBase *CB, unsigned ArgNo,
                               llvm::SmallVectorImpl<llvm::Function *> &Out,
                               unsigned MaxDepth = 4) {
  std::set<detail::FunctionArgPair> Visited;
  return detail::resolveFunctionPointerArgumentImpl(CB, ArgNo, Out, MaxDepth,
                                                    Visited);
}

/// Whether argument ArgNo of G is passed on, directly or through further
/// forwarding functions (up to MaxDepth levels), to a function for which
/// IsAnnotated returns true.
inline bool forwardsArgumentToAnnotated(
    llvm::Function *G, unsigned ArgNo,
    llvm::function_ref<bool(llvm::Function *)> IsAnnotated,
    unsigned MaxDepth = 4) {
  std::set<detail::FunctionArgPair> Visited;
  return detail::forwardsArgumentToAnnotatedImpl(G, ArgNo, IsAnnotated,
                                                 MaxDepth, Visited);
}

} // namespace utils
} // namespace compiler
} // namespace hipsycl

#endif
