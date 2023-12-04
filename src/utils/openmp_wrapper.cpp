#ifdef _OPENMP

#include <LightGBM/utils/openmp_wrapper.h>
#include <LightGBM/utils/log.h>

#include <omp.h>

// this can only be changed by LGBM_SetMaxThreads()
int LGBM_MAX_NUM_THREADS = -1;

// this is modified by OMP_SET_NUM_THREADS(), for example
// by passing num_thread through params
//
// NOTE: initializing this to 1 cuts the ratio by about 2x... so maybe
//       some things are getting a number of threads based on this?
//       or maybe this is being copied around to multiple places?
int LGBM_DEFAULT_NUM_THREADS = -1;

void OMP_SET_NUM_THREADS(int num_threads) {
  if (num_threads <= 0) {
    LightGBM::Log::Info("OMP_SET_NUM_THREADS() line 46: LGBM_MAX_NUM_THREADS=%i, num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, num_threads, LGBM_DEFAULT_NUM_THREADS);
    LGBM_DEFAULT_NUM_THREADS = -1;
    LightGBM::Log::Info("OMP_SET_NUM_THREADS() line 48: LGBM_MAX_NUM_THREADS=%i, num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, num_threads, LGBM_DEFAULT_NUM_THREADS);
  } else {
    LightGBM::Log::Info("OMP_SET_NUM_THREADS() line 50: LGBM_MAX_NUM_THREADS=%i, num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, num_threads, LGBM_DEFAULT_NUM_THREADS);
    LGBM_DEFAULT_NUM_THREADS = num_threads;
    LightGBM::Log::Info("OMP_SET_NUM_THREADS() line 52: LGBM_MAX_NUM_THREADS=%i, num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, num_threads, LGBM_DEFAULT_NUM_THREADS);
  }
  LightGBM::Log::Info("OMP_SET_NUM_THREADS() line 54: LGBM_MAX_NUM_THREADS=%i, num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, num_threads, LGBM_DEFAULT_NUM_THREADS);
}

#endif  // _OPENMP
