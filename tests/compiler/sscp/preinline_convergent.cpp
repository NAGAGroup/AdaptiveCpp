// A helper that wraps a group barrier is not marked convergent by stage 1, which
// compiles device code as host C++. The pre-inline simplification would then
// thread the repeated `g < n` branch through the helper's call and duplicate the
// barrier into both arms, so work-items that take different arms would wait at
// different barriers. The barrier must stay a single call.
//
// RUN: %acpp %s -o %t --acpp-targets=generic -O3
// RUN: rm -f %t.ll
// RUN: env ACPP_S2_DUMP_IR_JIT_OPTIMIZATIONS=%t.ll %t | FileCheck %s --check-prefix=OUT
// RUN: FileCheck %s --input-file %t.ll

#include "common.hpp"
#include <iostream>

constexpr size_t L = 8;

static void wrap_barrier(sycl::nd_item<1> it) {
  sycl::group_barrier(it.get_group());
}

// Items past n still reach the barrier; only their reads and writes are guarded.
static void body(sycl::nd_item<1> it, sycl::local_accessor<float, 1> tile,
                 const float *x, float *y, size_t n) {
  const size_t g = it.get_global_id(0);
  const size_t l = it.get_local_id(0);
  tile[l] = g < n ? x[g] : 0.0f;
  wrap_barrier(it);
  if (g < n)
    y[g] = tile[L - 1 - l];
}

int main() {
  sycl::queue q = get_queue();

  constexpr size_t n = 12;
  constexpr size_t global = 16;
  float host_x[global];
  float host_y[global];
  for (size_t i = 0; i < global; ++i) {
    host_x[i] = static_cast<float>(i + 1);
    host_y[i] = -1.0f;
  }

  float *x = sycl::malloc_device<float>(global, q);
  float *y = sycl::malloc_device<float>(global, q);
  q.memcpy(x, host_x, sizeof(host_x)).wait();
  q.memcpy(y, host_y, sizeof(host_y)).wait();

  q.submit([&](sycl::handler &h) {
     sycl::local_accessor<float, 1> tile{sycl::range<1>{L}, h};
     h.parallel_for(sycl::nd_range<1>{global, L}, [=](sycl::nd_item<1> it) {
       body(it, tile, x, y, n);
     });
   }).wait();

  q.memcpy(host_y, y, sizeof(host_y)).wait();

  // Each group of L reverses its own elements; reads past n see 0, and y is
  // untouched (-1) from n on.
  bool ok = true;
  for (size_t i = 0; i < global; ++i) {
    const size_t group = i / L, l = i % L;
    float want = -1.0f;
    if (i < n) {
      const size_t src = group * L + (L - 1 - l);
      want = src < n ? static_cast<float>(src + 1) : 0.0f;
    }
    if (host_y[i] != want) {
      ok = false;
      std::cout << "mismatch at " << i << ": " << host_y[i] << " != " << want
                << std::endl;
    }
  }

  // OUT: OK
  std::cout << (ok ? "OK" : "FAILED") << std::endl;

  sycl::free(x, q);
  sycl::free(y, q);
  return ok ? 0 : 1;
}

// The dump taken right after the always-inliner: the barrier is still a call to
// the builtin there, and the kernel holds exactly one of them.
//
// CHECK-LABEL: stage: jit_optimizations
// CHECK-LABEL: define {{.*}}__acpp_sscp_kernel
// CHECK-COUNT-1: call {{.*}}@__acpp_sscp_work_group_barrier
// CHECK-NOT: call {{.*}}@__acpp_sscp_work_group_barrier
// CHECK: ret void
