#ifdef _OPENMP

#include <LightGBM/utils/openmp_wrapper.h>
#include <LightGBM/utils/log.h>

#include <omp.h>

// this can only be changed by LGBM_SetMaxThreads()
int LGBM_MAX_NUM_THREADS = 1;

// this is modified by OMP_SET_NUM_THREADS(), for example
// by passing num_thread through params
int LGBM_DEFAULT_NUM_THREADS = -1;

// NOTE: it's important that OMP_NUM_THREADS() be inlined, as it's used in OpenMP pragmas
//       and some compilers will not generate lazy-evaluation of this function in those contexts
int OMP_NUM_THREADS() {
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
    *default_num_threads = LGBM_DEFAULT_NUM_THREADS;
    LightGBM::Log::Info("OMP_NUM_THREADS() line 24: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  } else {
    // otherwise, default to OpenMP-global config
    #pragma omp parallel
    // ref: https://curc.readthedocs.io/en/latest/programming/OpenMP-C.html
    // map running this back on the master thread leads to a wrong conclusion
    // about how many threads to use?
    #pragma omp master
    { *default_num_threads = omp_get_max_threads(); }
    LightGBM::Log::Info("OMP_NUM_THREADS() line 30: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
  }

  // ensure that if LGBM_SetMaxThreads() was ever called, LightGBM doesn't
  // use more than that many threads
  if (LGBM_MAX_NUM_THREADS > 0 and default_num_threads > LGBM_MAX_NUM_THREADS) {
    LightGBM::Log::Info("OMP_NUM_THREADS() line 36: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);
    return 2;
    //return LGBM_MAX_NUM_THREADS;
  }
  LightGBM::Log::Info("OMP_NUM_THREADS() line 39: LGBM_MAX_NUM_THREADS=%i, default_num_threads=%i, LGBM_DEFAULT_NUM_THREADS=%i", LGBM_MAX_NUM_THREADS, default_num_threads, LGBM_DEFAULT_NUM_THREADS);

  return default_num_threads;
}

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
