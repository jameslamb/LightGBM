int LGBM_MAX_NUM_THREADS = -1;

int LGBM_DEFAULT_NUM_THREADS = -1;

#ifdef _OPENMP

#include <LightGBM/utils/openmp_wrapper.h>

void OMP_SET_NUM_THREADS(int num_threads) {
  if (num_threads <= 0) {
    LGBM_DEFAULT_NUM_THREADS = -1;
  } else {
    LGBM_DEFAULT_NUM_THREADS = num_threads;
  }
}

#endif  // _OPENMP
