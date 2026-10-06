// UNSUPPORTED: system-darwin
// RUN: %acpp %s %S/second_tu.cpp -o %t --acpp-targets=generic
// RUN: %t | FileCheck %s
// RUN: %acpp %s %S/second_tu.cpp -o %t --acpp-targets=generic -O3
// RUN: %t | FileCheck %s
// RUN: %acpp %s %S/second_tu.cpp -o %t --acpp-targets=generic -g
// RUN: %t | FileCheck %s

// Dynamic function definitions that live in another translation unit. They are
// named only in the dynamic function configuration, not called by the kernel, so
// the JIT compiler has to link them from the other translation unit's exported
// symbols (SYCL_EXTERNAL).

#include <iostream>
#include <sycl/sycl.hpp>
#include "../common.hpp"

// defined in second_tu.cpp
SYCL_EXTERNAL void ext_set42(int* out, sycl::item<1> idx);
SYCL_EXTERNAL void ext_add1(int* out, sycl::item<1> idx);
SYCL_EXTERNAL void ext_add2(int* out, sycl::item<1> idx);
SYCL_EXTERNAL void ext_indexed0(int* out, int k, sycl::item<1> idx);
SYCL_EXTERNAL void ext_indexed1(int* out, int k, sycl::item<1> idx);

// dynamic functions, without definition in this translation unit
void define_fn(int* out, sycl::item<1> idx);
void sequence_fn(int* out, sycl::item<1> idx);
void indexed_fn(int* out, int k, sycl::item<1> idx);

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

  // define: one definition from the other translation unit
  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define(&define_fn, &ext_set42);
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      define_fn(data, idx);
    }));
  });
  // CHECK: 42 0 0

  // a plain call sequence of definitions from the other translation unit
  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_call_sequence(&sequence_fn, {&ext_add1, &ext_add2});
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      sequence_fn(data, idx);
    }));
  });
  // CHECK: 3 0 0

  // an indexed call sequence of definitions from the other translation unit:
  // definition k writes to out[k]
  run_and_print(q, data, [&]() {
    sycl::AdaptiveCpp_jit::dynamic_function_config cfg;
    cfg.define_as_indexed_call_sequence(&indexed_fn, {&ext_indexed0, &ext_indexed1}, 1);
    q.parallel_for(sycl::range{1}, cfg.apply([=](sycl::item<1> idx){
      indexed_fn(data, 99, idx);
    }));
  });
  // CHECK: 5 6 0

  sycl::free(data, q);
}
