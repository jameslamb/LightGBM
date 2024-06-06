#!/bin/bash

set -eou pipefail

repair-macos-wheel() {
    local wheel_file=$1
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

repair-macos-wheel "${1}"
