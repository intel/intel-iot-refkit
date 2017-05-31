DESCRIPTION = "ViennaCL linear algebra library"
SUMMARY = "ViennaCL: OpenCL accelerated linear algebra library"
HOMEPAGE = "http://viennacl.sourceforge.net/"
LICENSE = "MIT"
PRIORITY= "optional"
SECTION = "libs"
PR = "r0"

SRC_URI = " \
    https://github.com/viennacl/viennacl-dev/archive/release-1.7.1.zip \
    file://0001-examples-install-also-benchmarks-and-tutorials.patch \
"
SRC_URI[md5sum] = "aab7a159c7a45466cf5b1b569aed8b49"
SRC_URI[sha256sum] = "8e3f4377e3a815a25c45af5fe94f01f1927f6dfc3f258035d4a5db15b15d6866"

LIC_FILES_CHKSUM = "file://LICENSE;md5=02f8300a8eef6ede5cbc35fdec63f2a1"
DEPENDS = "boost virtual/opencl-icd virtual/opencl-headers"

S = "${WORKDIR}/viennacl-dev-release-${PV}"

inherit cmake

EXTRA_OECMAKE = " \
    -DBUILD_TESTING=OFF \
    -DBUILD_DOXYGEN_DOCS=OFF \
    -DENABLE_UBLAS=ON \
"

# this is a headers-only recipe
RDEPENDS_${PN}-dev = ""

do_install_append() {
    # copy test data into place
    install -d ${D}${datadir}/${PN}/examples
    cp -r ${S}/examples/testdata ${D}${datadir}/${PN}/examples/
}

FILES_${PN}-dev += " \
    ${libdir}/cmake \
"

PACKAGES += "${PN}-examples"

FILES_${PN}-examples += " \
    ${bindir}/* \
    ${datadir}/${PN}/examples \
"

FILES_${PN} = ""
