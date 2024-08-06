docker run \
    --rm \
    -v $(pwd):/opt/LightGBM \
    -w /opt/LightGBM \
    -it lightgbm/vsts-agent:manylinux_2_28_x86_64 \
    bash

rm -rf ./build ./lib_lightgbm.so
cmake -B build -S . -DCMAKE_CXX_VISIBILITY_PRESET=hidden -DCMAKE_C_VISIBILITY_PRESET=hidden
VERBOSE=1 cmake --build build --target _lightgbm -j4

readelf --symbols --wide --demangle ./lib_lightgbm.so > ./new.txt

summarize-symbols() {
    echo -n "GLOBAL: "
    echo $(cat $1 | grep 'GLOBAL' | wc -l)
    echo -n "LOCAL: "
    echo $(cat $1 | grep 'LOCAL' | wc -l)
    echo -n "WEAK: "
    echo $(cat $1 | grep 'WEAK' | wc -l)
}

