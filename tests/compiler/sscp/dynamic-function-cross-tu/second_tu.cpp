#include <sycl/sycl.hpp>

// Definitions for dynamic functions used from cross_tu.cpp. SYCL_EXTERNAL
// exports them for linking by the JIT compiler.

SYCL_EXTERNAL void ext_set42(int* out, sycl::item<1> idx) {
  out[0] = 42;
}

SYCL_EXTERNAL void ext_add1(int* out, sycl::item<1> idx) {
  out[0] += 1;
}

SYCL_EXTERNAL void ext_add2(int* out, sycl::item<1> idx) {
  out[0] += 2;
}

SYCL_EXTERNAL void ext_indexed0(int* out, int k, sycl::item<1> idx) {
  out[k] += 5;
}

SYCL_EXTERNAL void ext_indexed1(int* out, int k, sycl::item<1> idx) {
  out[k] += 6;
}
