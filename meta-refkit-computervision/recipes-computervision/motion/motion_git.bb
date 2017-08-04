DESCRIPTION = "Motion is a program that monitors the video signal from cameras."
HOMEPAGE = "https://motion-project.github.io/"
LICENSE = "GPLv2"
SECTION = "utils"
DEPENDS = "jpeg zlib"

inherit pkgconfig cmake

SRC_URI = " \
    git://github.com/Motion-Project/motion.git;protocol=https \
    file://0001-CMakeLists.txt-enable-out-of-tree-building.patch \
"
SRCREV = "ab9e800d5984f2907f00bebabc794d1dba9682ad"

LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"

S = "${WORKDIR}/git"

EXTRA_OECMAKE += "-DWITH_FFMPEG=OFF"

FILES_${PN}_append = " /usr/etc"
