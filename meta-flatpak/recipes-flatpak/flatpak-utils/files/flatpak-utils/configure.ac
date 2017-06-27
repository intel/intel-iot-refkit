
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

AC_INIT([flatpak-utils], m4_esyscmd([build-aux/git-version-gen .tarball-version]))

AC_CONFIG_SRCDIR([src])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADER([src/config.h])
AM_INIT_AUTOMAKE([-Wno-portability subdir-objects foreign])

AC_SUBST(ACLOCAL_AMFLAGS, "-I m4")

m4_define(version_major, `echo $VERSION | cut -d. -f1 | cut -d- -f1`)
m4_define(version_minor, `echo $VERSION | cut -d. -f2 | cut -d- -f1`)
m4_define(version_patch, `echo $VERSION | cut -d. -f3 | cut -d- -f1`)

AC_SUBST(VERSION)
AC_SUBST(VERSION_MAJOR, version_major)
AC_SUBST(VERSION_MINOR, version_minor)
AC_SUBST(VERSION_PATCH, version_patch)
AC_SUBST(VERSION_FULL, version_major.version_minor.version_patch)

IOT_VERSION_INFO="0:0:0"
AC_SUBST(IOT_VERSION_INFO)

# Disable static libraries.
AC_DISABLE_STATIC

# Checks for programs.
AC_PROG_CC
AC_PROG_CC_C99
AC_PROG_INSTALL
AC_PROG_LN_S
AM_PROG_CC_C_O
AM_PROG_LIBTOOL

# Guesstimate native compiler if we're cross-compiling.
if test "$cross_compiling" != "no"; then
    AC_MSG_NOTICE([Looks like we're being cross-compiled...])
    if test -z "$CC_FOR_BUILD"; then
        CC_FOR_BUILD=cc
    fi
else
    AC_MSG_NOTICE([Looks like we're doing a native compilation...])
    CC_FOR_BUILD='$(CC)'
fi
AC_SUBST(CC_FOR_BUILD)
UNSHAVED_CC_FOR_BUILD="$CC_FOR_BUILD"

# Make first invocation of PKG_CHECK_MODULES 'if-then-else-fi'-safe.
PKG_PROG_PKG_CONFIG

# Checks for header files.
AC_PATH_X
AC_CHECK_HEADERS([stdio.h stdlib.h errno.h fcntl.h sys/types.h sys/stat.h])

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

# Check for flatpak libraries.
PKG_CHECK_MODULES(FLATPAK, flatpak)

# Allow substitution for LIBDIR and SYSCONFDIR.
AC_MSG_CHECKING([libdir])
AC_MSG_RESULT([$libdir])
AC_SUBST(LIBDIR, [$libdir])
AC_MSG_CHECKING([sysconfdir])
AC_MSG_RESULT([$sysconfdir])
AC_SUBST(SYSCONFDIR, [$sysconfdir])

# Shave by default.
SHAVE_INIT([build-aux], [enable])

# Generate output.
AC_CONFIG_FILES([
        build-aux/shave
        build-aux/shave-libtool
        Makefile
        src/Makefile
    ])
AC_OUTPUT

# Display the configuration.
echo "----- configuration -----"
echo "Extra C warnings flags: $WARNING_CFLAGS"
echo "Cross-compiling: $cross_compiling"
if test "$cross_compiling" != "no"; then
    echo "     * native compiler: $UNSHAVED_CC_FOR_BUILD"
fi
echo "Systemd unitdir: $SYSTEMD_UNITDIR"
