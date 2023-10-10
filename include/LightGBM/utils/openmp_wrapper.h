/*!
 * Copyright (c) 2017 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_OPENMP_WRAPPER_H_
#define LIGHTGBM_OPENMP_WRAPPER_H_

#ifdef _OPENMP

#include <LightGBM/utils/log.h>

#include <limits.h>
#include <omp.h>

#include <exception>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <vector>

// this can only be changed by LGBM_SetMaxThreads()
static int LGBM_MAX_NUM_THREADS = -1;

// // this is controlled by OMP_SET_NUM_THREADS()
// static int LGBM_DEFAULT_NUM_THREADS = ;

// inline int OMP_NUM_THREADS() {

//   // if this is the first time this value has been accessed,
//   // set to OpenMP maximum 
//   if (LGBM_MAX_NUM_THREADS <= 0) {
//     LGBM_MAX_NUM_THREADS = omp_get_max_threads();
//   }

//   // use default number of OpenMP threads
//   int omp_default_num_threads

//   // only fall back to omp_get_num_threads() if LightGBM-specific
//   // maximum number of threads hasn't been configured
//   if (LGBM_MAX_NUM_THREADS > 0) {
//     return LGBM_MAX_NUM_THREADS;
//   }
//   int omp_default_num_threads = 1;
// #pragma omp parallel
// #pragma omp master
//   { omp_default_num_threads = omp_get_num_threads(); }
//   return ret;
// }

// inline void OMP_SET_NUM_THREADS(int num_threads) {
//     // if (num_threads <= 0) {
//     //     LGBM_MAX_NUM_THREADS = -1;
//     //     return;
//     // }
//     // LGBM_MAX_NUM_THREADS = num_threads;

//   static const int default_omp_num_threads = OMP_NUM_THREADS();
//   if (num_threads > 0) {
//     LGBM_MAX_NUM_THREADS = num_threads;
//     omp_set_num_threads(num_threads);
//   } else {
//     LGBM_MAX_NUM_THREADS = -1;
//     omp_set_num_threads(default_omp_num_threads);
//   }
// }

inline int OMP_NUM_THREADS() {
  int ret = 1;
#pragma omp parallel
#pragma omp master
  { ret = omp_get_num_threads(); }
  // try enforcing a maximum
  if (ret > 2) {
    return 2;
  }
  return ret;
}

inline void OMP_SET_NUM_THREADS(int num_threads) {
  static const int default_omp_num_threads = OMP_NUM_THREADS();
  if (num_threads > 0) {
    omp_set_num_threads(num_threads);
  } else {
    omp_set_num_threads(default_omp_num_threads);
  }
}

class ThreadExceptionHelper {
 public:
  ThreadExceptionHelper() {
    ex_ptr_ = nullptr;
  }

  ~ThreadExceptionHelper() {
    ReThrow();
  }
  void ReThrow() {
    if (ex_ptr_ != nullptr) {
      std::rethrow_exception(ex_ptr_);
    }
  }
  void CaptureException() {
    // only catch first exception.
    if (ex_ptr_ != nullptr) { return; }
    std::unique_lock<std::mutex> guard(lock_);
    if (ex_ptr_ != nullptr) { return; }
    ex_ptr_ = std::current_exception();
  }

 private:
  std::exception_ptr ex_ptr_;
  std::mutex lock_;
};

#define OMP_INIT_EX() ThreadExceptionHelper omp_except_helper
#define OMP_LOOP_EX_BEGIN() try {
#define OMP_LOOP_EX_END()                 \
  }                                       \
  catch (std::exception & ex) {           \
    Log::Warning(ex.what());              \
    omp_except_helper.CaptureException(); \
  }                                       \
  catch (...) {                           \
    omp_except_helper.CaptureException(); \
  }
#define OMP_THROW_EX() omp_except_helper.ReThrow()

#else

/*
 * To be compatible with OpenMP, define a nothrow macro which is used by gcc
 * openmp, but not by clang.
 * See also https://github.com/dmlc/dmlc-core/blob/3106c1cbdcc9fc9ef3a2c1d2196a7a6f6616c13d/include/dmlc/omp.h#L14
 */
#if defined(__clang__)
#undef __GOMP_NOTHROW
#define __GOMP_NOTHROW
#elif defined(__cplusplus)
#undef __GOMP_NOTHROW
#define __GOMP_NOTHROW throw()
#else
#undef __GOMP_NOTHROW
#define __GOMP_NOTHROW __attribute__((__nothrow__))
#endif

#ifdef _MSC_VER
  #pragma warning(disable : 4068)  // disable unknown pragma warning
#endif

#ifdef __cplusplus
  extern "C" {
#endif
  /** Fall here if no OPENMP support, so just
      simulate a single thread running.
      All #pragma omp should be ignored by the compiler **/
  inline void omp_set_num_threads(int) __GOMP_NOTHROW {}  // NOLINT (no cast done here)
  inline void OMP_SET_NUM_THREADS(int) __GOMP_NOTHROW {}
  inline int omp_get_num_threads() __GOMP_NOTHROW {return 1;}
  inline int omp_get_max_threads() __GOMP_NOTHROW {return 1;}
  inline int omp_get_thread_num() __GOMP_NOTHROW {return 0;}
  inline int OMP_NUM_THREADS() __GOMP_NOTHROW { return 1; }
  static int LGBM_MAX_NUM_THREADS = 1;
#ifdef __cplusplus
}  // extern "C"
#endif

#define OMP_INIT_EX()
#define OMP_LOOP_EX_BEGIN()
#define OMP_LOOP_EX_END()
#define OMP_THROW_EX()

#endif



#endif /* LIGHTGBM_OPENMP_WRAPPER_H_ */
