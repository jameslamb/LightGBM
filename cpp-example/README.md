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
```

TODO: find and remove the installed `lib_lightgbm.so` (`/tmp/lightgbm`)
