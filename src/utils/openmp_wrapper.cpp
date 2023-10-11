#ifdef _OPENMP

#include <LightGBM/utils/openmp_wrapper.h>
#include <LightGBM/utils/log.h>

#include <omp.h>

// this can only be changed by LGBM_SetMaxThreads()
int LGBM_MAX_NUM_THREADS = 1;

// this is modified by OMP_SET_NUM_THREADS(), for example
// by passing num_thread through params
int LGBM_DEFAULT_NUM_THREADS = -1;

int OMP_NUM_THREADS() {
  // this works for everything, so it's gott be the MAX_ mechanism that isn't working
  //return 1;
  int default_num_threads;

  if (LGBM_DEFAULT_NUM_THREADS > 0) {
    Log::Info("line 21: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
    // if LightGBM-specific default has been set, ignore OpenMP-global config
    default_num_threads = LGBM_DEFAULT_NUM_THREADS;
    Log::Info("line 24: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  } else {
    // otherwise, default to OpenMP-global config
    #pragma omp parallel
    #pragma omp master
    { default_num_threads = omp_get_max_threads(); }
    Log::Info("line 30: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  }

  // ensure that if LGBM_SetMaxThreads() was ever called, LightGBM doesn't
  // use more than that many threads
  if (LGBM_MAX_NUM_THREADS > 0 and default_num_threads > LGBM_MAX_NUM_THREADS) {
    Log::Info("line 36: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
    return LGBM_MAX_NUM_THREADS;
  }
  Log::Info("line 39: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);

  return default_num_threads;
}

void OMP_SET_NUM_THREADS(int num_threads) {
  if (num_threads <= 0) {
    LGBM_DEFAULT_NUM_THREADS = -1;
  } else {
    LGBM_DEFAULT_NUM_THREADS = num_threads;
  }
}

#endif  // _OPENMP
