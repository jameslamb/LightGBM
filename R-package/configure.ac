### configure.ac                    -*- Autoconf -*-

# References:
#    * https://unconj.ca/blog/an-autoconf-primer-for-r-package-authors.html
*    

AC_PREREQ(2.69)

AC_INIT([lightgbm],[2.3.2], [], [lightgbm], [])

# set up CPP flags
# Find the compiler and compiler flags used by R.
: ${R_HOME=`R RHOME`}
if test -z "${R_HOME}"; then
  echo "could not determine R_HOME"
  exit 1
fi
CC=`"${R_HOME}/bin/R" CMD config CC`
CFLAGS=`"${R_HOME}/bin/R" CMD config CFLAGS`
CPPFLAGS=`"${R_HOME}/bin/R" CMD config CPPFLAGS`

##############
# LGB_RFLAGS #
##############
LGB_RFLAGS=""

AC_MSG_CHECKING([whether using R version 3.5.0 or later])
ac_pkg_r35=no
R_35_OR_ABOVE=$(
    ${R_HOME}/bin/Rscript -e "
        R_ver <- as.double(R.version[['major']]) + as.double(R.version[['minor']]) / 10.0;
        cat(as.character(R_ver > 3.5))
    "
)
if test ${R_35_OR_ABOVE} = "TRUE"
then
    ac_pkg_r35=yes
    LGB_RFLAGS+=" -DR_VER_ABOVE_35"
fi
AC_MSG_RESULT([${ac_pkg_r35}])

# Compile for GPU?
AC_ARG_ENABLE(
    [gpu],
    AS_HELP_STRING(
        [--enable-gpu],
        [Pass this flag to install the R package for usage with GPU]
    ),
    [
        LGB_RFLAGS+=" -DUSE_GPU"
    ]
)

OPENMP_CXXFLAGS=""

if test `uname -s` = "Linux"
then
    OPENMP_CXXFLAGS="\$(SHLIB_OPENMP_CXXFLAGS)"
fi

if test `uname -s` = "Darwin"
then
    OPENMP_CXXFLAGS='-Xclang -fopenmp'
    OPENMP_LIB='/usr/local/lib/libomp.dylib'
    ac_pkg_openmp=no
    AC_MSG_CHECKING([whether OpenMP will work in a package])
    AC_LANG_CONFTEST(
        [
            AC_LANG_PROGRAM(
                [[
                    #include <omp.h>
                ]],
                [[
                    return (omp_get_max_threads() <= 1);
                ]]
            )
        ]
    )
    ${CC} -o conftest conftest.c /usr/local/lib/libomp.dylib -Xclang -fopenmp 2>/dev/null && ./conftest && ac_pkg_openmp=yes
    AC_MSG_RESULT([${ac_pkg_openmp}])
    if test "${ac_pkg_openmp}" = no; then
        OPENMP_CXXFLAGS=''
        OPENMP_LIB=''
        echo '***********************************************************************************************'
        echo 'WARNING: OpenMP is unavailable on this Mac OSX system. LightGBM code may be slower as a result.'
        echo '         To use all CPU cores for training jobs, you should install OpenMP by running\n'
        echo '             brew install libomp'
        echo '***********************************************************************************************'
    fi
fi

# substitute variables from this script into Makevars.in
AC_SUBST(OPENMP_CXXFLAGS)
AC_SUBST(OPENMP_LIB)
AC_SUBST(LGB_RFLAGS)
AC_CONFIG_FILES([src/Makevars])

# write out Autoconf output
AC_OUTPUT
