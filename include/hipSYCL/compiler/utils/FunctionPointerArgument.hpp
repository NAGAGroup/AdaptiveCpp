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
//
// The forwarding may pass the parameter directly, or through its unoptimised
// stack slot (the parameter is stored to an alloca and reloaded before use).

#ifndef ACPP_COMPILER_UTILS_FUNCTION_POINTER_ARGUMENT_HPP
#define ACPP_COMPILER_UTILS_FUNCTION_POINTER_ARGUMENT_HPP

#include <llvm/ADT/STLFunctionalExtras.h>
#include <llvm/ADT/SmallPtrSet.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/IR/Argument.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/GlobalAlias.h>
#include <llvm/IR/InstrTypes.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IntrinsicInst.h>
#include <llvm/IR/Intrinsics.h>

#include <set>
#include <utility>

namespace hipsycl {
namespace compiler {
namespace utils {

namespace detail {

using FunctionArgPair = std::pair<const llvm::Function *, unsigned>;

// Without optimisation (the pass runs at pipeline start) a parameter is stored
// to a stack slot and reloaded before use. A slot that is written exactly once
// and otherwise only read holds the parameter itself, so the load can be
// replaced by the stored value. If the slot escapes or has several writers,
// V is returned unchanged.
inline llvm::Value *lookThroughSpill(llvm::Value *V, unsigned Depth = 8) {
  V = V->stripPointerCasts();

  auto *L = llvm::dyn_cast<llvm::LoadInst>(V);
  if (!L || Depth == 0)
    return V;

  auto *A = llvm::dyn_cast<llvm::AllocaInst>(
      L->getPointerOperand()->stripPointerCasts());
  if (!A)
    return V;

  unsigned NumStores = 0;
  llvm::Value *Stored = nullptr;
  for (llvm::User *U : A->users()) {
    if (auto *S = llvm::dyn_cast<llvm::StoreInst>(U)) {
      if (S->getPointerOperand()->stripPointerCasts() == A &&
          S->getValueOperand() != A) {
        ++NumStores;
        Stored = S->getValueOperand();
        continue;
      }
      return V;
    }
    if (auto *L2 = llvm::dyn_cast<llvm::LoadInst>(U)) {
      if (L2->getPointerOperand()->stripPointerCasts() == A)
        continue;
      return V;
    }
    if (auto *II = llvm::dyn_cast<llvm::IntrinsicInst>(U))
      if (II->getIntrinsicID() == llvm::Intrinsic::lifetime_start ||
          II->getIntrinsicID() == llvm::Intrinsic::lifetime_end)
        continue;
    // The slot escapes.
    return V;
  }

  if (NumStores != 1)
    return V;
  return lookThroughSpill(Stored, Depth - 1);
}

inline bool resolveFunctionPointerArgumentImpl(
    llvm::CallBase *CB, unsigned ArgNo,
    llvm::SmallVectorImpl<llvm::Function *> &Out, unsigned MaxDepth,
    std::set<FunctionArgPair> &Visited) {
  if (!CB || ArgNo >= CB->arg_size())
    return false;

  llvm::Value *V = lookThroughSpill(CB->getArgOperand(ArgNo));

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

  // The value may be forwarded as the Argument itself or as a load of its
  // spill slot, so the candidate call sites are the users of the Argument plus
  // the users of every load of the slot the Argument is stored to.
  llvm::SmallVector<llvm::User *, 8> Candidates;
  llvm::SmallPtrSet<llvm::User *, 8> Seen;
  auto AddCandidate = [&](llvm::User *U) {
    if (Seen.insert(U).second)
      Candidates.push_back(U);
  };
  for (llvm::User *U : Arg->users()) {
    AddCandidate(U);
    if (auto *S = llvm::dyn_cast<llvm::StoreInst>(U)) {
      auto *A = llvm::dyn_cast<llvm::AllocaInst>(
          S->getPointerOperand()->stripPointerCasts());
      if (!A)
        continue;
      for (llvm::User *AU : A->users())
        if (auto *L = llvm::dyn_cast<llvm::LoadInst>(AU))
          for (llvm::User *LU : L->users())
            AddCandidate(LU);
    }
  }

  for (llvm::User *U : Candidates) {
    auto *CB2 = llvm::dyn_cast<llvm::CallBase>(U);
    if (!CB2)
      continue;
    llvm::Function *H = CB2->getCalledFunction();
    if (!H)
      continue;

    for (unsigned j = 0; j < CB2->arg_size(); ++j) {
      if (lookThroughSpill(CB2->getArgOperand(j)) != Arg)
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
