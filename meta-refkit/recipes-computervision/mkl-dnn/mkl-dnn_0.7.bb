DESCRIPTION = "Intel(R) Math Kernel Library for Deep Neural Networks"
HOMEPAGE = "https://01.org/mkl-dnn"
LICENSE = "Apache-2.0 & BSD-3-Clause"
SECTION = "libs"
DEPENDS = ""

inherit cmake

PN_MKLML = "mklml_lnx_2018.0.20170425"

SRC_URI = " \
    https://github.com/01org/${PN}/archive/v${PV}.tar.gz \
    https://github.com/01org/${PN}/releases/download/v${PV}/${PN_MKLML}.tgz;name=mklml \
    file://0001-build-add-soname-to-library.patch \
"

SRC_URI[md5sum] = "f3ff5ea16bc9a37a0db34fa75fd8a2b7"
SRC_URI[sha256sum] = "72fb2a533996d1218b7dfb9e11acf8a6d4a95bf28e277194dfea5648ecfa47c0"

SRC_URI[mklml.md5sum] = "5aecff839e853a9bb74cb34dd93c1f5d"
SRC_URI[mklml.sha256sum] = "3cc2501fb209e1fd0960a5f61c919438f9619c68a644dcebf0fdf69b07460c57"

LIC_FILES_CHKSUM = " \
    file://LICENSE;md5=e3fc50a88d0a364313df4b21ef20c29e \
    file://${WORKDIR}/${PN_MKLML}/license.txt;md5=67e50fd1d690e2951c06c4be76dda021 \
"

do_configure_prepend() {
    install -d ${S}/external
    rm -f ${S}/external/${PN_MKLML}
    ln -s ${WORKDIR}/${PN_MKLML} ${S}/external/${PN_MKLML}
}
