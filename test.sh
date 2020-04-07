#!/bin/sh

pushd $(pwd)/R-package
    autoconf \
        --verbose \
        --output configure \
        configure.ac || exit -1
popd

Rscript build_r.R --skip-install

#--configure-args='--enable-gpu' \
# --configure-args='CC=/usr/local/bin/gcc-8 CXX=/usr/local/bin/g++-8' \

R CMD INSTALL \
    lightgbm_2.3.2.tar.gz || exit -1

pushd $(pwd)/R-package/tests
    Rscript testthat.R
popd
