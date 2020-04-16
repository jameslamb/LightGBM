#!/bin/bash

# set up R environment
CRAN_MIRROR="https://cloud.r-project.org/"
R_LIB_PATH=~/Rlib
mkdir -p $R_LIB_PATH
echo "R_LIBS=$R_LIB_PATH" > ${HOME}/.Renviron
export PATH="$R_LIB_PATH/R/bin:$PATH"

# installing precompiled R for Ubuntu
# https://cran.r-project.org/bin/linux/ubuntu/#installation
# adding steps from https://stackoverflow.com/a/56378217/3986677 to get latest version
#
# This only needs to get run on Travis because R environment for Linux
# used by Azure pipelines is set up in https://github.com/guolinke/lightgbm-ci-docker
if [[ $TRAVIS == "true" ]] && [[ $OS_NAME == "linux" ]]; then
    sudo add-apt-repository \
        "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/"
    sudo apt-key adv \
        --keyserver keyserver.ubuntu.com \
        --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
    sudo apt-get update
    sudo apt-get install \
        --no-install-recommends \
        -y \
            r-base-dev=${R_TRAVIS_LINUX_VERSION} \
            texinfo \
            texlive-latex-recommended \
            texlive-fonts-recommended \
            texlive-fonts-extra \
            qpdf \
            || exit -1
fi

# Installing R precompiled for Mac OS 10.11 or higher
if [[ $OS_NAME == "macos" ]]; then

    # temp fix for basictex
    if [[ $AZURE == "true" ]]; then
        brew update
        # Azure Mac images aren't built with the macOS SDK headers enabled
        if [[ $R_BUILD_TYPE == "cran" ]]; then
            sudo installer \
            -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg \
            -target /
        fi
    fi

    brew install automake
    brew install qpdf
    brew cask install basictex
    export PATH="/Library/TeX/texbin:$PATH"
    sudo tlmgr --verify-repo=none update --self
    sudo tlmgr --verify-repo=none install inconsolata helvetic

    wget -q https://cran.r-project.org/bin/macosx/R-${R_MAC_VERSION}.pkg -O R.pkg
    sudo installer \
        -pkg $(pwd)/R.pkg \
        -target /

    # Fix "duplicate libomp versions" issue on Mac
    # by replacing the R libomp.dylib with a symlink to the one installed with brew
    if [[ $COMPILER == "clang" ]]; then
        ver_arr=( ${R_MAC_VERSION//./ } )
        R_MAJOR_MINOR="${ver_arr[0]}.${ver_arr[1]}"
        sudo ln -sf \
            "$(brew --cellar libomp)"/*/lib/libomp.dylib \
            /Library/Frameworks/R.framework/Versions/${R_MAJOR_MINOR}/Resources/lib/libomp.dylib
    fi
fi

conda install \
    -y \
    -q \
    --no-deps \
        pandoc

# Manually install Depends and Imports libraries + 'testthat'
# to avoid a CI-time dependency on devtools (for devtools::install_deps())
packages="c('data.table', 'jsonlite', 'Matrix', 'R6', 'testthat')"
if [[ $OS_NAME == "macos" ]]; then
    packages+=", type = 'binary'"
fi
Rscript --vanilla -e "install.packages(${packages}, repos = '${CRAN_MIRROR}', lib = '${R_LIB_PATH}', dependencies = c('Depends', 'Imports', 'LinkingTo'))" || exit -1

cd ${BUILD_DIRECTORY}

PKG_TARBALL="lightgbm_${LGB_VER}.tar.gz"
if [[ $R_BUILD_TYPE == "cmake" ]]; then
    Rscript build_r.R --skip-install || exit -1
elif [[ $R_BUILD_TYPE == "cran" ]]; then
    ./build-cran-package.sh || exit -1
    # Test CRAN source .tar.gz in a directory that is not this repo or below it.
    # When people install.packages('lightgbm'), the won't have the LightGBM
    # git repo around. This is to protect against the use of relative paths
    # like ../../CMakeLists.txt that would only work if you are in the repoo
    R_CMD_CHECK_DIR="${HOME}/tmp-r-cmd-check/"
    mkdir -p ${R_CMD_CHECK_DIR}
    mv ${PKG_TARBALL} ${R_CMD_CHECK_DIR}
    cd ${R_CMD_CHECK_DIR}
fi

# suppress R CMD check warning from Suggests dependencies not being available
export _R_CHECK_FORCE_SUGGESTS_=0

# fails tests if either ERRORs or WARNINGs are thrown by
# R CMD CHECK
check_succeeded="true"
R CMD check ${PKG_TARBALL} \
    --as-cran \
|| check_succeeded="false"

echo "---- R CMD check logs ----"
cat lightgbm.Rcheck/00install.out

if [[ $check_succeeded == "false" ]]; then
    exit -1
fi

LOG_FILE_NAME="lightgbm.Rcheck/00check.log"
if grep -q -R "WARNING" "$LOG_FILE_NAME"; then
    echo "WARNINGS have been found by R CMD check!"
    exit -1
fi

ALLOWED_CHECK_NOTES=3
NUM_CHECK_NOTES=$(
    cat ${LOG_FILE_NAME} \
        | grep -e '^Status: .* NOTE.*' \
        | sed 's/[^0-9]*//g'
)
if [[ ${NUM_CHECK_NOTES} -gt ${ALLOWED_CHECK_NOTES} ]]; then
    echo "Found ${NUM_CHECK_NOTES} NOTEs from R CMD check. Only ${ALLOWED_CHECK_NOTES} are allowed"
    exit -1
fi

exit 0
