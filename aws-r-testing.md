Got a `c5a.4xlarge` instance.


```shell
ssh \
    -i ${HOME}/.aws/gpu-testing-2.cer \
    ubuntu@ec2-35-91-7-48.us-west-2.compute.amazonaws.com
```

```shell
sudo apt-get update
sudo apt-get install --no-install-recommends -y \
    software-properties-common

sudo apt-get install --no-install-recommends -y \
    apt-utils \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    iputils-ping \
    jq \
    libcurl4 \
    libicu-dev \
    libomp-dev \
    libssl-dev \
    libunwind8 \
    locales \
    locales-all \
    netcat \
    unzip \
    zip

export LANG="en_US.UTF-8"
sudo update-locale LANG=${LANG}
export LC_ALL="${LANG}"

# set up R environment
export CRAN_MIRROR="https://cran.rstudio.com"
export MAKEFLAGS=-j8
export R_LIB_PATH=~/Rlib
export R_LIBS=$R_LIB_PATH
export PATH="$R_LIB_PATH/R/bin:$PATH"
export R_APT_REPO="jammy-cran40/"
export R_LINUX_VERSION="4.3.1-1.2204.0"

mkdir -p $R_LIB_PATH

mkdir -p ~/.gnupg
echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
sudo apt-key adv \
    --homedir ~/.gnupg \
    --keyserver keyserver.ubuntu.com \
    --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

sudo add-apt-repository \
    "deb ${CRAN_MIRROR}/bin/linux/ubuntu ${R_APT_REPO}"

sudo apt-get update
sudo apt-get install \
    --no-install-recommends \
    -y \
        autoconf \
        automake \
        devscripts \
        r-base-core=${R_LINUX_VERSION} \
        r-base-dev=${R_LINUX_VERSION} \
        texinfo \
        texlive-latex-extra \
        texlive-latex-recommended \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        tidy \
        qpdf

# install dependencies
Rscript \
    --vanilla \
    -e "install.packages(c('data.table', 'jsonlite', 'knitr', 'Matrix', 'R6', 'RhpcBLASctl', 'rmarkdown', 'testthat'), repos = '${CRAN_MIRROR}', lib = '${R_LIB_PATH}', dependencies = c('Depends', 'Imports', 'LinkingTo'), Ncpus = parallel::detectCores())"

# build LightGBM
mkdir -p ${HOME}/repos
cd ${HOME}/repos
git clone --recursive https://github.com/microsoft/LightGBM.git
cd ./LightGBM
sh build-cran-package.sh --no-build-vignettes

# here we go...
OMP_NUM_THREADS=16 \
_R_CHECK_EXAMPLE_TIMING_THRESHOLD_=0 \
_R_CHECK_EXAMPLE_TIMING_CPU_TO_ELAPSED_THRESHOLD_=2.5 \
R --vanilla CMD check \
    --no-codoc \
    --no-manual \
    --no-tests \
    --no-vignettes \
    --run-dontrun \
    --run-donttest \
    --timings \
    ./lightgbm_4.1.0.99.tar.gz
```

With `gcc 11.4.0`, that did not reproduce the issues.

```text
Examples with CPU (user + system) or elapsed time > 0s
                             user system elapsed
lgb.plot.interpretation     0.477  0.000   0.251
lgb.interprete              0.404  0.009   0.176
lgb.Dataset.create.valid    0.284  0.024   0.060
slice                       0.300  0.000   0.045
lgb.Dataset                 0.247  0.005   0.043
readRDS.lgb.Booster         0.190  0.011   0.062
set_field                   0.197  0.000   0.046
lgb.importance              0.170  0.023   0.125
lgb.Dataset.set.categorical 0.191  0.001   0.035
get_field                   0.189  0.001   0.046
lgb.Dataset.save            0.175  0.006   0.035
lgb.cv                      0.168  0.002   0.106
lgb.configure_fast_predict  0.162  0.000   0.051
lgb.model.dt.tree           0.140  0.000   0.109
lgb.Dataset.construct       0.131  0.004   0.035
lgb.Dataset.set.reference   0.124  0.005   0.034
saveRDS.lgb.Booster         0.121  0.000   0.091
lgb.plot.importance         0.120  0.000   0.083
lgb.convert_with_rules      0.112  0.000   0.016
dimnames.lgb.Dataset        0.087  0.015   0.040
lgb.load                    0.097  0.004   0.060
predict.lgb.Booster         0.096  0.000   0.055
lgb.restore_handle          0.078  0.000   0.059
lgb.dump                    0.076  0.000   0.053
lgb.train                   0.075  0.000   0.052
lgb.get.eval.result         0.073  0.000   0.052
lgb.save                    0.073  0.000   0.053
dim                         0.034  0.012   0.046
```

I noticed that the errors CRAN reported to us were with `clang`:

```text
** libs
using C++ compiler: ‘Debian clang version 16.0.6 (3)’
```

https://win-builder.r-project.org/incoming_pretest/lightgbm_4.0.0_20230716_163050/Debian/00install.out

Installed `clang` and tried again

```shell
sudo apt-get install -y --no-install-recommends \
    clang \
    lldb

mkdir -p ${HOME}/.R

cat << EOF > ${HOME}/.R/Makevars
CC=clang
CXX=clang++
CXX17=clang++
EOF

OMP_NUM_THREADS=16 \
_R_CHECK_EXAMPLE_TIMING_THRESHOLD_=0 \
_R_CHECK_EXAMPLE_TIMING_CPU_TO_ELAPSED_THRESHOLD_=2.5 \
R --vanilla CMD check \
    --no-codoc \
    --no-manual \
    --no-tests \
    --no-vignettes \
    --run-dontrun \
    --run-donttest \
    --timings \
    ./lightgbm_4.1.0.99.tar.gz
```

Testing stuff via the Python package.

```shell
apt-get install -y python3-pip python3.10-venv
alias pip=pip3
alias python=python3
```

Script to test

```r
library(lightgbm)

lightgbm::setLGBMthreads(3L)


X <- matrix(rnorm(1e6), ncol=1e2)
y <- rnorm(nrow(X))

dtrain <- lightgbm::lgb.Dataset(
    data = X
    , label = y
    , params = list(
        min_data_in_bin = 5L
        , max_bins = 128L
    )
)

bst <- lightgbm::lgb.train(
    data = dtrain
    , params = list(
        objective = "regression"
        , num_iterations = 100L
        , verbosity = 1L
    )
)

print("max threads: ")
print(lightgbm::getLGBMthreads())
```

```shell
cd ${HOME}/repos/LightGBM && \
git pull jlamb fix/thread-control && \
sh build-cran-package.sh --no-build-vignettes && \
R CMD INSTALL \
  --with-keep.source \
  lightgbm_4.1.0.99.tar.gz

# OMP_THREAD_LIMIT=1 \

rm ./traces.out
for i in 1 2 6 8 16; do
    OMP_MAX_ACTIVE_LEVELS=${i} \
    OMP_NUM_THREADS=16 \
        Rscript --vanilla ./check-multithreading.R ${i}
done
cat ./traces.out
```

## Things that didn't work:

* removing all the `#pragma omp` calls:
    - ... in `LightGBM_R.cpp`
    - ... from `DatasetCreateFromMats()` in `c_api.cpp`
    - ... in `include/bin.h`
    - ... in `include/common.h`
    - ... in `include/feature_group.sh`
    - ... in `include/LightGBM/tree.h`
    - ... in `include/utils/threading.h`
    - ... in `src/application/*`
    - ... in `src/boosting/*`
    - ... in `src/io/*`
    - ... in `src/metric/*`
    - ... in `src/objective/*`
    - ... in `src/treelearner/*`
    - ... in `src/c_api.cpp`

## Notes

Calling `OMP_NUM_THREADS()`, as I've currently writtten it, seems to result in multithreading being enabled.

Removing all OpenMP pragmas.... still seeing parallelism (12-16 threads).

Then removing `OMP_NUM_THREADS()` calls in log messages... no more parallelism!

HMMMMM.

OH MY GOD I THINK I FIGURED IT OUT.

Needs to be this:

```text
#pragma omp single
{ default_num_threads = omp_get_max_threads(); }
```

Instead of this:

```text

```

## References

* https://docs.oracle.com/cd/E19205-01/819-5270/aewbc/index.html#:~:text=Nested%20parallelism%20can%20be%20enabled,levels%20of%20nested%20parallel%20constructs.
* https://stackoverflow.com/a/6934050/3986677
* https://princetonuniversity.github.io/PUbootcamp/sessions/parallel-programming/Intro_PP_bootcamp_2018.pdf
* https://www.openmp.org/spec-html/5.0/openmpsu35.html#x55-880002.6.1
    - how the `if` and `num_threads()` clauses are evaluated
    - if `if()` is false, only 1 thread is used
* https://www.openmp.org/spec-html/5.0/openmpse23.html#x117-4350002.15
* https://stackoverflow.com/a/11884188/3986677
* all operations: https://www.openmp.org/wp-content/uploads/OpenMP-4.0-C.pdf
