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

# Compile for GPU?
LGB_RFLAGS=""
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

# substitute variables from this script into Makevars.in
AC_SUBST(OPENMP_CXXFLAGS)
AC_SUBST(OPENMP_LIB)
AC_SUBST(LGB_RFLAGS)
AC_CONFIG_FILES([src/Makevars])

# write out Autoconf output
AC_OUTPUT
