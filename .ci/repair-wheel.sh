#!/bin/bash

set -eou pipefail

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

    # set RPATH hints teling the linker to look in the following places (in this order)
    #
    #   1. right next to wherver lib_lightgbm.dylib is ()
    install_name_tool \
        -change \
        "${omp_library}" \
        '@rpath/libomp.dylib' \
        ./lightgbm/lib/lib_lightgbm.dylib

    # add RPATHs to find libomp.dylib
    install_name_tool \
        -add_rpath \
        '@rpath/' \
        ./lightgbm/lib/lib_lightgbm.dylib

    omp_library_dir=$(dirname "${omp_library}")
    install_name_tool \
        -add_rpath \
        "${omp_library_dir}" \
        ./lightgbm/lib/lib_lightgbm.dylib

    zip -r $(basename "${wheel_file}") .

    popd
}

repair-macos-wheel "${1}"
