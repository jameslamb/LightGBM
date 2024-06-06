XGBoost was against it a few years ago:

* https://github.com/dmlc/xgboost/issues/6494

```shell
xgb_wheel="https://files.pythonhosted.org/packages/03/e6/4aef6799badc2693548559bad5b56d56cfe89eada337c815fdfe92175250/xgboost-2.0.3-py3-none-macosx_12_0_arm64.whl"

wget \
    -O ./xgb.whl \
    ${xgb_wheel}

unzip \
    -d ./tmp \
    ./xgb.whl

otool -L ./tmp/xgboost/lib/libxgboost.dylib
```

```text
./tmp/xgboost/lib/libxgboost.dylib:
        @rpath/libxgboost.dylib (compatibility version 0.0.0, current version 0.0.0)
        @loader_path/../.dylibs/libomp.dylib (compatibility version 5.0.0, current version 5.0.0)
        /usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 1300.36.0)
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1319.0.0)
```

lightgbm

```shell
rm -rf ./build
cmake -B build -S .
cmake --build build --target _lightgbm -j4
otool -L ./lib_lightgbm.dylib
```

```text
./lib_lightgbm.dylib:
        @rpath/lib_lightgbm.dylib (compatibility version 0.0.0, current version 0.0.0)
        /opt/homebrew/opt/libomp/lib/libomp.dylib (compatibility version 5.0.0, current version 5.0.0)
        /usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 1700.255.0)
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)
```

Test script:

```shell
sh build-python.sh install --precompile
python -c "from sklearn.datasets import make_regression; import lightgbm as lgb; X, y = make_regression(); lgb.train(params={}, train_set=lgb.Dataset(X, label=y), num_boost_round=5)"
# Segmentation fault: 11
```

When that library is loaded in a conda environment that also has another copy of OpenMP installed, it leads to a segfault.

```text
Segmentation fault: 11
```

```shell
find /Users/jlamb/miniforge3 -name 'libomp.dylib*'
# /Users/jlamb/miniforge3/pkgs/llvm-openmp-18.1.3-hcd81f8e_0/lib/libomp.dylib
# /Users/jlamb/miniforge3/pkgs/llvm-openmp-18.1.5-hde57baf_0/lib/libomp.dylib
# /Users/jlamb/miniforge3/envs/treelite-dev/lib/libomp.dylib
# /Users/jlamb/miniforge3/envs/lgb-dev/lib/libomp.dylib
# /Users/jlamb/miniforge3/envs/lgb-nightly-dev/lib/python3.12/site-packages/sklearn/.dylibs/libomp.dylib
```

But using it in a Python environment from outside of conda world, it works.

```shell
/opt/homebrew/bin/pip3.11 install \
    --prefer-binary \
    scikit-learn \
    numpy \
    scipy

/opt/homebrew/bin/pip3.11 uninstall \
    --yes \
    lightgbm

# /opt/homebrew/bin/pip3.11 install --no-deps \
#     ./dist/lightgbm-4.3.0.99-py3-none-macosx_14_0_arm64.whl

/opt/homebrew/bin/pip3.11 install --no-deps \
    ./dist/lightgbm-4.3.0.99.tar.gz

DYLD_PRINT_LIBRARIES=1 \
DYLD_PRINT_STATISTICS=1 \
/opt/homebrew/bin/python3.11 \
    -c "from sklearn.datasets import make_regression; import lightgbm as lgb; X, y = make_regression(); lgb.train(params={}, train_set=lgb.Dataset(X, label=y), num_boost_round=5)"
```

```shell
CMAKE_BUILD_PARALLEL_LEVEL=4 \
sh build-python.sh bdist_wheel

# still segfaults
delocate-wheel \
    --dylibs-only \
    --sanitize-rpaths \
    --lib-sdir 'vendored-libs' \
    -w ./dist_repaired \
    ./dist/lightgbm-4.3.0.99-py3-none-macosx_14_0_arm64.whl
```

Patching that path...

```shell
repair-macos-wheel() {
    wheel_file=$1
    mkdir -p ./staging
    unzip \
        -d ./staging \
        "${wheel_file}"

    pushd ./staging
    omp_library=$(
        otool -L ./lightgbm/lib/lib_lightgbm.dylib \
        | awk '{$1=$1};1' \
        | grep -o -E '.*libomp\.dylib[0-9.]*'
    )
    install_name_tool \
        -change ${omp_library} \
        '@rpath/libomp.dylib' \
        ./lightgbm/lib/lib_lightgbm.dylib

    # set RPATH hints teling the linker to look in the following places:
    #
    #   1. right next to wherever lib_lightgbm.dylib is ()
    install_name_tool \
        -add_rpath \
        '@rpath/libomp.dylib' \
        ./lightgbm/lib/lib_lightgbm.dylib

    # 2. wherever homebrew put OpenMP
    install_name_tool \
        -add_rpath \
        "${omp_library}" \
        ./lightgbm/lib/lib_lightgbm.dylib

    zip -r $(basename "${wheel_file}") .

    popd
}

repair-macos-wheel \
    dist/lightgbm-4.3.0.99-py3-none-macosx_14_0_arm64.whl
```

```shell
DYLD_PRINT_LIBRARIES=1 \
DYLD_PRINT_RPATHS=1 \
python \
    -c "from sklearn.datasets import make_regression; import lightgbm as lgb; X, y = make_regression(); lgb.train(params={}, train_set=lgb.Dataset(X, label=y), num_boost_round=5)"
```

References:

* https://discuss.python.org/t/conflicting-binary-extensions-in-different-packages/25332/2
* https://stackoverflow.com/questions/3146274/is-it-ok-to-use-dyld-library-path-on-mac-os-x-and-whats-the-dynamic-library-s
* http://clarkkromenaker.com/post/library-dynamic-loading-mac/
* https://cmake.org/pipermail/cmake/2019-September/069996.html
* https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling
* https://stackoverflow.com/questions/73263834/cmake-how-to-set-rpath-in-a-shared-library-with-only-target-link-directories-w
* https://stackoverflow.com/questions/43330165/how-to-link-a-shared-library-with-cmake-with-relative-path/43333118#43333118
* https://stackoverflow.com/a/51504440/3986677
* https://github.com/dmlc/xgboost/pull/7621
* https://github.com/scikit-learn/scikit-learn/pull/21227
* https://github.com/dmlc/xgboost/issues/7355
