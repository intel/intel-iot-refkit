SUMMARY = "Python library that provides an easy interface to read and write a wide range of image data, including animated images, video, volumetric data, and scientific formats."
SECTION = "devel/python"
LICENSE = "PIL"
LIC_FILES_CHKSUM = "file://LICENSE;md5=ed22148166c9fd21895d7794dc16f6a5"

inherit setuptools3 pkgconfig distutils-tools

SRC_URI = " \
    https://github.com/python-pillow/Pillow/archive/${PV}a.tar.gz \
    file://0001-build-always-disable-platform-guessing.patch \
"

SRC_URI[md5sum] = "bca20cd48afd6618135540b34dba3267"
SRC_URI[sha256sum] = "d498837f6c84d0fad9ef414dc0e9ee0b8d45d10efebc72898ed15950f111ad55"

S = "${WORKDIR}/Pillow-${PV}a"

DEPENDS += "python3 libjpeg-turbo zlib tiff freetype libpng jpeg"

# DISTUTILS_INSTALL_ARGS += "--disable-platform-guessing"

CFLAGS_append = " -I${STAGING_INCDIR}"
LDFLAGS_append = " -L${STAGING_LIBDIR}"

do_compile_prepend() {
    export LDFLAGS="$LDFLAGS -L${STAGING_LIBDIR}"
    export CFLAGS="$CFLAGS -I${STAGING_INCDIR}"
}
