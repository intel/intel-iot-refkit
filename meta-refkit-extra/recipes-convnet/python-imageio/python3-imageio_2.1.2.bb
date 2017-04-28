SUMMARY = "Python library that provides an easy interface to read and write a wide range of image data, including animated images, video, volumetric data, and scientific formats."
SECTION = "devel/python"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=295e673459dd7498500c971c98831367"

SRC_URI = " \
    https://github.com/imageio/imageio/archive/v${PV}.tar.gz \
"
SRC_URI[md5sum] = "61bb19fa36d966c2dc85521948b338c9"
SRC_URI[sha256sum] = "d7d411c25e2b46af99b6bbca7eb00cc9847981db12f467f6c8d9e7d7a80b277b"

S = "${WORKDIR}/imageio-${PV}"

inherit setuptools3

DEPENDS = "python3"

RDEPENDS_${PN} = "python3-numpy python3-pillow"

