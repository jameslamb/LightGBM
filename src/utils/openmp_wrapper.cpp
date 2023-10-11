#ifdef _OPENMP

#include <LightGBM/utils/openmp_wrapper.h>
#include <LightGBM/utils/log.h>

#include <omp.h>

// this can only be changed by LGBM_SetMaxThreads()
static int LGBM_MAX_NUM_THREADS = -1;

// this is modified by OMP_SET_NUM_THREADS(), for example
// by passing num_thread through params
static int LGBM_DEFAULT_NUM_THREADS = -1;

static int OMP_NUM_THREADS() {
  int default_num_threads;

  if (LGBM_DEFAULT_NUM_THREADS > 0) {
    // if LightGBM-specific default has been set, ignore OpenMP-global config
    default_num_threads = LGBM_DEFAULT_NUM_THREADS;
  } else {
    // otherwise, default to OpenMP-global config
    #pragma omp parallel
    #pragma omp master
    { default_num_threads = omp_get_max_threads(); }
  }

  // ensure that if LGBM_SetMaxThreads() was ever called, LightGBM doesn't
  // use more than that many threads
  if (LGBM_MAX_NUM_THREADS > 0 and default_num_threads > LGBM_MAX_NUM_THREADS) {
    return LGBM_MAX_NUM_THREADS;
  }

  return default_num_threads;
}

static void OMP_SET_NUM_THREADS(int num_threads) {
  if (num_threads <= 0) {
    LGBM_DEFAULT_NUM_THREADS = -1;
  } else {
    LGBM_DEFAULT_NUM_THREADS = num_threads;
  }
}

#endif  // _OPENMP