// UNSUPPORTED: system-darwin
// RUN: %acpp %s -o %t --acpp-targets=generic
// RUN: %t | FileCheck %s
// RUN: %acpp %s -o %t --acpp-targets=generic -O3
// RUN: %t | FileCheck %s
// RUN: %acpp %s -o %t --acpp-targets=generic -g
// RUN: %t | FileCheck %s

// Indexed call sequences: definition k of the sequence is called with the
// arguments of the call, except that the argument at the index position is
// replaced by the constant k. Every definition adds a distinct weight to
// out[k], so a definition that received a wrong index writes to a wrong slot.

#include <iostream>
#include <sycl/sycl.hpp>
#include "common.hpp"

// ---- one definition: the wrapper is also built for a single definition -------
SYCL_EXTERNAL void single_def0(int* out, int k, sycl::item<1> idx) {
  out[k] += 7;
}
void single_seq(int* out, int k, sycl::item<1> idx);

// ---- two definitions ---------------------------------------------------------
SYCL_EXTERNAL void two_def0(int* out, int k, sycl::item<1> idx) {
  out[k] += 1;
}
SYCL_EXTERNAL void two_def1(int* out, int k, sycl::item<1> idx) {
  out[k] += 10;
}
void two_seq(int* out, int k, sycl::item<1> idx);

// ---- three definitions -------------------------------------------------------
SYCL_EXTERNAL void three_def0(int* out, int k, sycl::item<1> idx) {
  out[k] += 1;
}
SYCL_EXTERNAL void three_def1(int* out, int k, sycl::item<1> idx) {
  out[k] += 10;
}
SYCL_EXTERNAL void three_def2(int* out, int k, sycl::item<1> idx) {
  out[k] += 100;
}
void three_seq(int* out, int k, sycl::item<1> idx);

// ---- the index is the first argument, and of a different integer type --------
SYCL_EXTERNAL void first_def0(unsigned short k, int* out, sycl::item<1> idx) {
  out[k] += 2;
}
SYCL_EXTERNAL void first_def1(unsigned short k, int* out, sycl::item<1> idx) {
  out[k] += 20;
}
void first_seq(unsigned short k, int* out, sycl::item<1> idx);

// ---- one kernel, two configurations that differ only in the index position ----
SYCL_EXTERNAL void swap_def0(int a, int b, int* out, sycl::item<1> idx) {
  out[a] += 1;
  out[b] += 2;
}
SYCL_EXTERNAL void swap_def1(int a, int b, int* out, sycl::item<1> idx) {
  out[a] += 10;
  out[b] += 20;
}
void swap_seq(int a, int b, int* out, sycl::item<1> idx);

// The same lambda (so the same kernel) is launched with both index positions: the
// two configurations must not share a cached binary.
void launch_swap(sycl::queue& q, int* data, int index_param) {
  sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
  cfg.define_as_indexed_call_sequence(&swap_seq, {&swap_def0, &swap_def1}, index_param);
  q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
    swap_seq(2, 2, data, idx);
  }));
}

template <class Run>
void run_and_print(sycl::queue& q, int* data, Run&& run) {
  q.memset(data, 0, 3 * sizeof(int)).wait();
  run();
  q.wait();

  int host[3];
  q.memcpy(host, data, 3 * sizeof(int)).wait();
  std::cout << host[0] << " " << host[1] << " " << host[2] << std::endl;
}

int main() {
  sycl::queue q = get_queue();
  int* data = sycl::malloc_device<int>(3, q);

  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_indexed_call_sequence(&single_seq, {&single_def0}, 1);
    // The value passed for the index (99) is replaced by the constant 0
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      single_seq(data, 99, idx);
    }));
  });
  // CHECK: 7 0 0

  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_indexed_call_sequence(&two_seq, {&two_def0, &two_def1}, 1);
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      two_seq(data, 99, idx);
    }));
  });
  // CHECK: 1 10 0

  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_indexed_call_sequence(&three_seq, {&three_def0, &three_def1, &three_def2}, 1);
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      three_seq(data, 99, idx);
    }));
  });
  // CHECK: 1 10 100

  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_indexed_call_sequence(&first_seq, {&first_def0, &first_def1}, 0);
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      first_seq(5, data, idx);
    }));
  });
  // CHECK: 2 20 0

  // index position 0: a is replaced by k, b stays 2
  run_and_print(q, data, [&]() { launch_swap(q, data, 0); });
  // CHECK: 1 10 22

  // index position 1: b is replaced by k, a stays 2
  run_and_print(q, data, [&]() { launch_swap(q, data, 1); });
  // CHECK: 2 20 11

  sycl::free(data, q);
}
