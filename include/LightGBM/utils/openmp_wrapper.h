/*!
 * Copyright (c) 2017 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_OPENMP_WRAPPER_H_
#define LIGHTGBM_OPENMP_WRAPPER_H_

#ifdef _OPENMP

#include <LightGBM/export.h>
#include <LightGBM/utils/log.h>

#include <limits.h>
#include <omp.h>

#include <exception>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <vector>

// this can only be changed by LGBM_SetMaxThreads()
LIGHTGBM_EXTERN_C int LGBM_MAX_NUM_THREADS;

// this is modified by OMP_SET_NUM_THREADS(), for example
// by passing num_thread through params
LIGHTGBM_EXTERN_C int LGBM_DEFAULT_NUM_THREADS;

/*
    Get number of threads to use in OpenMP parallel regions.

    By default, this will return the result of omp_get_max_threads(),
    which is OpenMP-implementation dependent but generally can be controlled
    by environment variable OMP_NUM_THREADS.

    ref:
      - https://www.openmp.org/spec-html/5.0/openmpsu112.html
      - https://gcc.gnu.org/onlinedocs/libgomp/omp_005fget_005fmax_005fthreads.html
*/
// int OMP_NUM_THREADS();
// NOTE: it's important that OMP_NUM_THREADS() be inlined, as it's used in OpenMP pragmas
//       and some compilers will not generate lazy-evaluation of this function in those contexts
inline int OMP_NUM_THREADS() {
  // uncommenting this fixes all the parallelism problems
  // (i.e., only 2 threads ever created)
  //
  // hardcoding this to any positive number seems to totally disable multiprocessing
  //
  //return 16;
  int default_num_threads;

  if (LGBM_DEFAULT_NUM_THREADS > 0) {
    LightGBM::Log::Info("OMP_NUM_THREADS() line 21: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
    // if LightGBM-specific default has been set, ignore OpenMP-global config
    default_num_threads = LGBM_DEFAULT_NUM_THREADS;
    LightGBM::Log::Info("OMP_NUM_THREADS() line 24: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  } else {
    // otherwise, default to OpenMP-global config
    #pragma omp parallel shared(default_num_threads)
    // ref: https://curc.readthedocs.io/en/latest/programming/OpenMP-C.html
    // map running this back on the master thread leads to a wrong conclusion
    // about how many threads to use?
    #pragma omp master
    { default_num_threads = omp_get_max_threads(); }
    LightGBM::Log::Info("OMP_NUM_THREADS() line 30: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  }

  // ensure that if LGBM_SetMaxThreads() was ever called, LightGBM doesn't
  // use more than that many threads
  if (LGBM_MAX_NUM_THREADS > 0 and default_num_threads > LGBM_MAX_NUM_THREADS) {
    LightGBM::Log::Info("OMP_NUM_THREADS() line 36: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
    return LGBM_MAX_NUM_THREADS;
  }
  LightGBM::Log::Info("OMP_NUM_THREADS() line 39: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);

  return default_num_threads;
}

void OMP_SET_NUM_THREADS(int num_threads);

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
  void OMP_SET_NUM_THREADS(int) __GOMP_NOTHROW {}
  inline int omp_get_thread_num() __GOMP_NOTHROW {return 0;}
  inline int OMP_NUM_THREADS() __GOMP_NOTHROW { return 1; }
  LIGHTGBM_EXTERN_C int LGBM_DEFAULT_NUM_THREADS = 1;
  LIGHTGBM_EXTERN_C int LGBM_MAX_NUM_THREADS = 1;
#ifdef __cplusplus
}  // extern "C"
#endif

#define OMP_INIT_EX()
#define OMP_LOOP_EX_BEGIN()
#define OMP_LOOP_EX_END()
#define OMP_THROW_EX()

#endif



#endif /* LIGHTGBM_OPENMP_WRAPPER_H_ */
