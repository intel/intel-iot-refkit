SUMMARY = "Python library that provides an easy interface to read and write a wide range of image data, including animated images, video, volumetric data, and scientific formats."
SECTION = "devel/python"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=295e673459dd7498500c971c98831367"

SRC_URI = " \
    https://github.com/imageio/imageio/archive/v${PV}.tar.gz;downloadfilename=${PN}-${PV}.tar.gz \
"
SRC_URI[md5sum] = "c375999eb6f96e9b7375940607d639ed"
SRC_URI[sha256sum] = "086cf1f171d4307f488cf38c82e4cf191f8260e425112bfa825f746b75e98d60"

S = "${WORKDIR}/imageio-${PV}"

inherit setuptools3

DEPENDS = "python3"

RDEPENDS_${PN} = "python3-numpy python3-pillow"

