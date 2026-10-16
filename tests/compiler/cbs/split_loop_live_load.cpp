// RUN: %acpp %s -o %t --acpp-targets=generic
// RUN: env ACPP_VISIBILITY_MASK=omp %t | FileCheck %s
// RUN: %acpp %s -o %t --acpp-targets=generic -O
// RUN: env ACPP_VISIBILITY_MASK=omp %t | FileCheck %s

// A per-lane value loaded from memory (b) stays live across the barriers of a loop of group reductions, and is multiplied by a
// k-dependent factor in every iteration. The loop is nested in an outer grid-stride loop that runs exactly once per group, with its
// bound loaded from memory. The load of b is part of several sub-CFGs, and the one after the last barrier must restore it from the
// work-item state array, not from a fresh single-element slot that only the first trip of the work-item loop has written.

#include <cmath>
#include <iostream>
#include <vector>

#include <sycl/sycl.hpp>

int main() {
  constexpr size_t local_size = 64;
  constexpr size_t groups     = 4;
  constexpr size_t K          = 8;

  sycl::queue queue;

  std::vector<float> host_x(groups * local_size), host_bm(K * local_size), host_out(groups * K, -1.0f);
  for (size_t i = 0; i < host_x.size(); ++i)
    host_x[i] = static_cast<float>(i % 7 + 1) * 0.5f;
  for (size_t k = 0; k < K; ++k)
    for (size_t l = 0; l < local_size; ++l)
      host_bm[k * local_size + l] = static_cast<float>((k * 7 + l * 3) % 11) * 0.1f;
  const unsigned host_bound = groups;

  float *x = sycl::malloc_device<float>(host_x.size(), queue);
  float *bm = sycl::malloc_device<float>(host_bm.size(), queue);
  float *out = sycl::malloc_device<float>(host_out.size(), queue);
  unsigned *params = sycl::malloc_device<unsigned>(1, queue);
  queue.memcpy(x, host_x.data(), host_x.size() * sizeof(float));
  queue.memcpy(bm, host_bm.data(), host_bm.size() * sizeof(float));
  queue.memcpy(out, host_out.data(), host_out.size() * sizeof(float));
  queue.memcpy(params, &host_bound, sizeof(host_bound)).wait();

  queue.parallel_for(
      sycl::nd_range<1>{groups * local_size, local_size}, [=](sycl::nd_item<1> item) {
        const size_t group = item.get_group(0);
        const size_t l = item.get_local_id(0);
        for (size_t lg = group; lg < params[0]; lg += groups) {
          const float b = x[lg * local_size + l];
          for (size_t k = 0; k < K; ++k) {
            const float s = sycl::reduce_over_group(
                item.get_group(), b * bm[k * local_size + l], sycl::plus<float>());
            if (l == 0)
              out[lg * K + k] = s;
          }
        }
      });
  queue.wait();
  queue.memcpy(host_out.data(), out, host_out.size() * sizeof(float)).wait();

  for (size_t g = 0; g < groups; ++g) {
    bool ok = true;
    for (size_t k = 0; k < K && ok; ++k) {
      double want = 0.0;
      for (size_t l = 0; l < local_size; ++l)
        want += static_cast<double>(host_x[g * local_size + l]) * host_bm[k * local_size + l];
      const float got = host_out[g * K + k];
      if (!(std::fabs(got - want) <= 1e-3 + 1e-4 * std::fabs(want))) {
        std::cout << "group " << g << ": FAIL k=" << k << " got " << got << " want " << want << "\n";
        ok = false;
      }
    }
    if (ok)
      std::cout << "group " << g << ": OK\n";
  }

  sycl::free(x, queue);
  sycl::free(bm, queue);
  sycl::free(out, queue);
  sycl::free(params, queue);
}

// CHECK: group 0: OK
// CHECK: group 1: OK
// CHECK: group 2: OK
// CHECK: group 3: OK
