### configure.ac                    -*- Autoconf -*-

# References:
#    * https://unconj.ca/blog/an-autoconf-primer-for-r-package-authors.html
*    

AC_PREREQ(2.69)

AC_INIT([lightgbm],[2.3.2], [], [lightgbm], [])

# Find the compiler and compiler flags used by R.
: ${R_HOME=`R RHOME`}
if test -z "${R_HOME}"; then
  echo "could not determine R_HOME"
  exit 1
fi
CC=`"${R_HOME}/bin/R" CMD config CC`
CFLAGS=`"${R_HOME}/bin/R" CMD config CFLAGS`
CPPFLAGS=`"${R_HOME}/bin/R" CMD config CPPFLAGS`

AC_SUBST(OPENMP_CXXFLAGS)
AC_SUBST(OPENMP_LIB)
AC_SUBST(ENDIAN_FLAG)
AC_SUBST(BACKTRACE_LIB)
AC_CONFIG_FILES([src/Makevars])
AC_OUTPUT
