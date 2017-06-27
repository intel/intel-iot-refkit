
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

AC_INIT([refkit-ostree], [0.0.0], [BUG-REPORT-ADDRESS])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADER([src/config.h])
AM_INIT_AUTOMAKE([-Wno-portability subdir-objects foreign])

AC_SUBST(ACLOCAL_AMFLAGS, "-I m4")

# Disable static libraries.
AC_DISABLE_STATIC

# Checks for programs.
AC_PROG_CC
AC_PROG_CC_C99
AC_PROG_INSTALL
AC_PROG_LN_S
AM_PROG_CC_C_O
AM_PROG_LIBTOOL

# Make first invocation of PKG_CHECK_MODULES 'if-then-else-fi'-safe.
PKG_PROG_PKG_CONFIG

# Checks for header files.
AC_PATH_X
AC_CHECK_HEADERS([stdio.h stdlib.h stdarg.h string.h locale.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.


# Check and enable extra compiler warnings if they are supported.
AC_ARG_ENABLE(extra-warnings,
              [  --enable-extra-warnings enable extra compiler warnings],
	      [extra_warnings=$enableval], [extra_warnings=auto])

WARNING_CFLAGS=""
warncflags="-Wall -Wextra"
if test "$extra_warnings" != "no"; then
    save_CPPFLAGS="$CPPFLAGS"
    for opt in $warncflags; do
        AC_PREPROC_IFELSE([AC_LANG_PROGRAM([])],
	                  [WARNING_CFLAGS="$WARNING_CFLAGS $opt"])
    done
    CPPFLAGS="$save_CPPFLAGS"
fi

AC_SUBST(WARNING_CFLAGS)

# Allow overriding systemds' unitdir.
AC_ARG_WITH([systemdunitdir],
        AC_HELP_STRING([--with-systemdunitdir=DIR], [systemd unit directory]),
        [with_systemdunitdir=${withval}],
	[with_systemdunitdir="`$PKG_CONFIG --variable=systemdsystemunitdir systemd`"])

if test -n "${with_systemdunitdir}"; then
	SYSTEMD_UNITDIR="${with_systemdunitdir}"
	AC_SUBST(SYSTEMD_UNITDIR)
fi

# Check for OSTree headers and libraries.
PKG_CHECK_MODULES(OSTREE, ostree-1)

# Allow substitution for LIBDIR and SYSCONFDIR.
AC_MSG_CHECKING([libdir])
AC_MSG_RESULT([$libdir])
AC_SUBST(LIBDIR, [$libdir])
AC_MSG_CHECKING([sysconfdir])
AC_MSG_RESULT([$sysconfdir])
AC_SUBST(SYSCONFDIR, [$sysconfdir])
AC_SUBST(DATADIR, [$datadir])

# Generate output.
AC_CONFIG_FILES([
        Makefile
    ])
AC_OUTPUT

# Display the configuration.
echo "----- configuration -----"
echo "Extra C warnings flags: $WARNING_CFLAGS"
echo "Cross-compiling: $cross_compiling"
echo "Systemd unitdir: $SYSTEMD_UNITDIR"
echo "OSTree libraries: $OSTREE_LIBS"
