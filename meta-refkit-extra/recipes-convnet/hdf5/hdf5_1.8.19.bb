DESCRIPTION = "Unique technology suite that makes possible the management of extremely large and complex data collections"
AUTHOR = "Alexander Leiva <norxander@gmail.com>"
SUMMARY = "HDF5 is a data model, library, and file format for storing and managing data"
HOMEPAGE = "http://caffe.berkeleyvision.org/"
LICENSE = "BSD"
PRIORITY= "optional"
SECTION = "libs"
PR = "r0"

RDEPENDS_${PN} = "zlib"

LIC_FILES_CHKSUM = "file://COPYING;md5=57e5351b17591e659eedae107265c606"

inherit cmake

SRC_URI = " \
    https://support.hdfgroup.org/ftp/HDF5/current18/src/${PN}-${PV}.tar.bz2 \
    file://configuration.patch \
    file://generation.patch \
    file://copy_generated.patch \
"

SRC_URI[md5sum] = "6f0353ee33e99089c110a1c8d2dd1b22"
SRC_URI[sha256sum] = "59c03816105d57990329537ad1049ba22c2b8afe1890085f0c022b75f1727238"

PACKAGES += "${PN}-extra"
FILES_${PN} += "/usr/lib/libhdf5.settings"
FILES_${PN}-extra = "/usr/share/hdf5_examples/"

# EXTRA_OECONF = "--enable-production --enable-cxx --with-zlib=${STAGING_INCDIR},${STAGING_LIBDIR}"
EXTRA_OECMAKE = " \
    -DHAVE_DEFAULT_SOURCE_RUN=0 \
    -DHAVE_DEFAULT_SOURCE_RUN__TRYRUN_OUTPUT= \
    -DTEST_LFS_WORKS_RUN=0 \
    -DTEST_LFS_WORKS_RUN__TRYRUN_OUTPUT=0 \
    -DH5_PRINTF_LL_TEST_RUN=1 \
    -DH5_PRINTF_LL_TEST_RUN__TRYRUN_OUTPUT='8' \
    -DTEST_DIRECT_VFD_WORKS_RUN=0 \
    -DTEST_DIRECT_VFD_WORKS_RUN__TRYRUN_OUTPUT=0 \
    -DH5_LDOUBLE_TO_LONG_SPECIAL_RUN=0 \
    -DH5_LDOUBLE_TO_LONG_SPECIAL_RUN__TRYRUN_OUTPUT= \
    -DH5_LONG_TO_LDOUBLE_SPECIAL_RUN=0 \
    -DH5_LONG_TO_LDOUBLE_SPECIAL_RUN__TRYRUN_OUTPUT= \
    -DH5_LDOUBLE_TO_LLONG_ACCURATE_RUN=0 \
    -DH5_LDOUBLE_TO_LLONG_ACCURATE_RUN__TRYRUN_OUTPUT= \
    -DH5_LLONG_TO_LDOUBLE_CORRECT_RUN=0 \
    -DH5_LLONG_TO_LDOUBLE_CORRECT_RUN__TRYRUN_OUTPUT= \
    -DH5_NO_ALIGNMENT_RESTRICTIONS_RUN=0 \
    -DH5_NO_ALIGNMENT_RESTRICTIONS_RUN__TRYRUN_OUTPUT= \
    -DCMAKE_INSTALL_PREFIX='${D}/usr' \
"

do_install() {
    oe_runmake install
    rm -f ${D}/usr/lib/*la
    rm -f ${D}/usr/share/cmake/*
    rm -f ${D}/usr/share/COPYING
    rm -f ${D}/usr/share/RELEASE.txt
    rm -f ${D}/usr/share/USING_HDF5_CMake.txt
    rmdir ${D}/usr/share/cmake
    rmdir ${D}/usr/share

    ln -sr ${D}/usr/lib/libhdf5_cpp-shared.so ${D}/usr/lib/libhdf5_cpp.so
    ln -sr ${D}/usr/lib/libhdf5_hl-shared.so ${D}/usr/lib/libhdf5_hl.so
    ln -sr ${D}/usr/lib/libhdf5_hl_cpp-shared.so ${D}/usr/lib/libhdf5_hl_cpp.so
    ln -sr ${D}/usr/lib/libhdf5-shared.so ${D}/usr/lib/libhdf5.so
    ln -sr ${D}/usr/lib/libhdf5_tools-shared.so ${D}/usr/lib/libhdf5_tools.so
}

