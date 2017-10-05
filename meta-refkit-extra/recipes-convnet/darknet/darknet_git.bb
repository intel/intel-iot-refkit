SUMMARY = "Darknet: Open Source Neural Networks in C"
DESCRIPTION = "Darknet is an open source neural network framework written in C."
HOMEPAGE="http://pjreddie.com/darknet/"
SECTION = "libs"
PRIORITY= "optional"
LICENSE = "PD"
PR = "r0"

LIC_FILES_CHKSUM = "file://LICENSE;md5=4714f70f7f315d04508e3fd63d9b9232"

SRC_URI = " \
    git://github.com/pjreddie/darknet.git;protocol=https \
    file://0001-Makefile-added-a-soname-to-the-libdarknet.so.patch \
"

SRCREV = "1e729804f61c8627eb257fba8b83f74e04945db7"

S = "${WORKDIR}/git"

inherit pkgconfig

PACKAGE_BEFORE_PN = "${PN}-data"

EXTRA_OEMAKE = " \
    'CC=${CC}' 'RANLIB=${RANLIB}' 'AR=${AR}' \
    'CFLAGS=${CFLAGS} -I${S}/include -DWITHOUT_XATTR -fPIC -Wall -Wno-unknown-pragmas -Wfatal-errors' \
    'BUILDDIR=${S}' \
    'LDFLAGS=${LDFLAGS} -lm -pthread' \
    'OPENMP=1' \
"

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${libdir}
    install -d ${D}${datadir}/${PN}/data
    install -d ${D}${datadir}/${PN}/cfg
    install ${S}/darknet ${D}${bindir}
    install ${S}/libdarknet.so.* ${D}${libdir}
    ln -sr ${D}${libdir}/libdarknet.so.0.0.1 ${D}${libdir}/libdarknet.so.0
    ln -sr ${D}${libdir}/libdarknet.so.0 ${D}${libdir}/libdarknet.so

    # include subdirectories
    cp -r ${S}/data/* ${D}${datadir}/${PN}/data
    cp -r ${S}/cfg/* ${D}${datadir}/${PN}/cfg
}

FILES_${PN}-data = "${datadir}"
