Compile and install LightGBM.

```shell
cmake \
    -B build \
    -S . \
    -DAPPLE_OUTPUT_DYLIB=ON \
    -DUSE_OPENMP=OFF \
    -DCMAKE_INSTALL_PREFIX=/tmp/lightgbm

cmake --build build --target install -j4
```

Compile the test program.

```shell
clang++ \
    -std=c++11 \
    -arch arm64 \
    -o ./lgb-train \
    -I/tmp/lightgbm/include \
    -I./external_libs/fast_double_parser/include \
    -I./external_libs/fmt/include \
    -l_lightgbm \
    -L/tmp/lightgbm/lib \
    -Wl,-rpath,/tmp/lightgbm/lib \
    ./cpp-example/main.cpp
```

Run the program.

```shell
./lgb-train
```

Which runs like this!

```text
[LightGBM] [Info] Loading initial scores...
[LightGBM] [Info] Construct bin mappers from text data time 0.02 seconds
[LightGBM] [Info] Auto-choosing row-wise multi-threading, the overhead of testing was 0.000345 seconds.
You can set `force_row_wise=true` to remove the overhead.
And if memory is not enough, you can set `force_col_wise=true`.
[LightGBM] [Info] Total Bins 6132
[LightGBM] [Info] Number of data points in the train set: 7000, number of used features: 28
```

And has a model file.

```text
cat ./model_example.txt
```

So, TODO:

* put up a PR fixing those relative include paths
* test this in CentOS 7 with `gcc`
* reply on https://github.com/microsoft/LightGBM/issues/6379
* and this one https://github.com/microsoft/LightGBM/issues/6261
* and this one https://github.com/microsoft/LightGBM/issues/5957
* delete that `/tmp/lightgbm`

TODO: find and remove the installed `lib_lightgbm.so` (`/tmp/lightgbm`)
