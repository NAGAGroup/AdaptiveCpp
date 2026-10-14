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
#ifndef HIPSYCL_LLVMUTILS_HPP
#define HIPSYCL_LLVMUTILS_HPP

#include <llvm/ADT/StringRef.h>
#include <llvm/IR/BasicBlock.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Instruction.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Module.h>
#if LLVM_VERSION_MAJOR < 16
#define IS_OPAQUE(pointer) (pointer->isOpaquePointerTy())
#define HAS_TYPED_PTR 1
#else
#define IS_OPAQUE(pointer) constexpr(true || pointer) /* Use `pointer` to silence warnings */
#define HAS_TYPED_PTR 0
#endif

namespace hipsycl::llvmutils {

inline bool starts_with(llvm::StringRef String, llvm::StringRef Prefix) {
#if LLVM_VERSION_MAJOR < 18
  return String.startswith(Prefix);
#else
  return String.starts_with(Prefix);
#endif
}

inline bool ends_with(llvm::StringRef String, llvm::StringRef Prefix) {
#if LLVM_VERSION_MAJOR < 18
  return String.endswith(Prefix);
#else
  return String.ends_with(Prefix);
#endif
}

inline auto makeInsertionPoint(llvm::Instruction *InsertionPt) {
#if LLVM_VERSION_MAJOR < 20
  return InsertionPt;
#else
  return InsertionPt->getIterator();
#endif
}

inline llvm::Instruction *getNextNonDebugInstruction(llvm::Instruction *I) {
#if LLVM_VERSION_MAJOR < 22
  return I->getNextNonDebugInstruction();
#else
  return I->getNextNode();
#endif
}

// Pointer type to \c Pointee in address space \c AS. With typed pointers (LLVM < 16) this is
// the pointee-typed pointer; otherwise it is the opaque pointer in \c Pointee's context.
// Replaces PointerType::get(Type*, unsigned) / getUnqual(Type*), deprecated in LLVM 23.
inline llvm::PointerType *getPointerTo(llvm::Type *Pointee, unsigned AS = 0) {
#if LLVM_VERSION_MAJOR < 16
  return llvm::PointerType::get(Pointee, AS);
#else
  return llvm::PointerType::get(Pointee->getContext(), AS);
#endif
}

// First non-PHI instruction of a block. getFirstNonPHI() is deprecated in favour of
// getFirstNonPHIIt() (iterator instruction positions, LLVM 20+).
inline llvm::Instruction *getFirstNonPHI(llvm::BasicBlock *BB) {
#if LLVM_VERSION_MAJOR < 20
  return BB->getFirstNonPHI();
#else
  return &*BB->getFirstNonPHIIt();
#endif
}

inline const llvm::Instruction *getFirstNonPHI(const llvm::BasicBlock *BB) {
#if LLVM_VERSION_MAJOR < 20
  return BB->getFirstNonPHI();
#else
  return &*BB->getFirstNonPHIIt();
#endif
}

// Instruction::moveBefore/insertBefore taking an Instruction* are deprecated in LLVM 23 in
// favour of the iterator overloads (available since LLVM 19; used from 20 as above).
inline void moveBefore(llvm::Instruction *I, llvm::Instruction *MovePos) {
#if LLVM_VERSION_MAJOR < 20
  I->moveBefore(MovePos);
#else
  I->moveBefore(MovePos->getIterator());
#endif
}

inline void insertBefore(llvm::Instruction *I, llvm::Instruction *InsertPos) {
#if LLVM_VERSION_MAJOR < 20
  I->insertBefore(InsertPos);
#else
  I->insertBefore(InsertPos->getIterator());
#endif
}

// Condition of a conditional branch, or nullptr if \c I is null or not a conditional branch.
// LLVM 23 split BranchInst into UncondBrInst/CondBrInst and deprecated BranchInst's accessors.
inline llvm::Value *getBranchCondition(const llvm::Instruction *I) {
#if LLVM_VERSION_MAJOR >= 23
  if (auto *Br = llvm::dyn_cast_or_null<llvm::CondBrInst>(I))
    return Br->getCondition();
#else
  if (auto *Br = llvm::dyn_cast_or_null<llvm::BranchInst>(I))
    if (Br->isConditional())
      return Br->getCondition();
#endif
  return nullptr;
}

// Unconditional branch to \c Dest, appended to \c InsertAtEnd.
inline llvm::Instruction *createBr(llvm::BasicBlock *Dest, llvm::BasicBlock *InsertAtEnd) {
#if LLVM_VERSION_MAJOR >= 23
  return llvm::UncondBrInst::Create(Dest, InsertAtEnd);
#else
  return llvm::BranchInst::Create(Dest, InsertAtEnd);
#endif
}

// Conditional branch on \c Cond, appended to \c InsertAtEnd.
inline llvm::Instruction *createCondBr(llvm::Value *Cond, llvm::BasicBlock *IfTrue,
                                       llvm::BasicBlock *IfFalse, llvm::BasicBlock *InsertAtEnd) {
#if LLVM_VERSION_MAJOR >= 23
  return llvm::CondBrInst::Create(Cond, IfTrue, IfFalse, InsertAtEnd);
#else
  return llvm::BranchInst::Create(IfTrue, IfFalse, Cond, InsertAtEnd);
#endif
}

// Remove all module-level inline assembly. setModuleInlineAsm(StringRef) no longer exists in
// LLVM 23 (it takes GlobalAsmFragment); removeModuleInlineAsm() is the replacement.
inline void clearModuleInlineAsm(llvm::Module &M) {
#if LLVM_VERSION_MAJOR >= 23
  M.removeModuleInlineAsm();
#else
  M.setModuleInlineAsm("");
#endif
}
} // namespace hipsycl::llvmutils

#endif // HIPSYCL_LLVMUTILS_HPP
