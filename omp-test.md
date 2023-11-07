
Compile:

```shell
export CC=clang
export CXX=clang++

rm -rf ./build && \
mkdir ./build && \
cd ./build && \
cmake -DUSE_OPENMP=ON .. && \
make -j3 _lightgbm && \
cd ..
```

Reinstall

```shell
alias python=python3
sh build-python.sh install --precompile
```

Test

```python
import ctypes
from lightgbm.basic import _LIB

# at initialization, should be -1
num_thread = ctypes.c_int(0)
ret = _LIB.LGBM_GetMaxThreads(
    ctypes.byref(num_thread)
)
assert ret == 0
assert num_thread.value == -1

# try setting it
ret = _LIB.LGBM_SetMaxThreads(
    ctypes.c_int(6)
)
assert ret == 0

ret = _LIB.LGBM_GetMaxThreads(
    ctypes.byref(num_thread)
)
assert ret == 0
assert num_thread.value == 6
```

Testing in R

```r
library(lightgbm)

# at initialization, should be -1
num_thread <- integer(1)
.Call(lightgbm:::LGBM_GetMaxThreads_R, num_thread)
stopifnot(num_thread == -1L)

# try setting it
.Call(lightgbm:::LGBM_SetMaxThreads_R, 6L)
.Call(lightgbm:::LGBM_GetMaxThreads_R, num_thread)
stopifnot(num_thread == 6L)
```

Find uses that don't control number of threads:

```shell
git grep 'pragma omp parallel' | grep -v num_threads
```
