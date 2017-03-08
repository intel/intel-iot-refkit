SUMMARY = "Python bindings for librealsense"
SECTION = "devel/python"
LICENSE = "Apache-2.0"

LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=3b83ef96387f14655fc854ddc3c6bd57"

inherit setuptools3

SRC_URI = " \
    https://github.com/toinsson/pyrealsense/archive/v${PV}.tar.gz \
    file://0001-setup.py-change-to-use-Bitbake-variables.patch \
    file://0002-constants-change-rs.h-search-location.patch \
"
SRC_URI[md5sum] = "a92627a58da523564289187ee05cd937"
SRC_URI[sha256sum] = "f06797af5aa9ca682858a783d42a0e1bc917d5dea50fb340f590d11a21d1a521"

S = "${WORKDIR}/pyrealsense-${PV}"

DEPENDS = "python3 python3-numpy-native librealsense python3-setuptools-native"
RDEPENDS_${PN} = "python3-numpy python3-pycparser librealsense-dev"

# the rs.h header file is parsed in runtime, thus the need for
# librealsense-dev
INSANE_SKIP_${PN} += "dev-deps"
