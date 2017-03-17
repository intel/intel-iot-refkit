SUMMARY = "Snappy is a compression/decompression library."
AUTHOR = "Alexander Leiva <norxander@gmail.com>"
DESCRIPTION = "Snappy is a compression/decompression library. It does not aim for maximum compression, \
				or compatibility with any other compression library; instead, \
				it aims for very high speeds and reasonable compression."
HOMEPAGE="http://google.github.io/snappy/"
SECTION = "console/utils"
PRIORITY= "optional"
LICENSE = "BSD"
PR = "r0"

LIC_FILES_CHKSUM = "file://COPYING;md5=f62f3080324a97b3159a7a7e61812d0c"

SRC_URI = "https://github.com/google/snappy/releases/download/${PV}/${PN}-${PV}.tar.gz"
SRC_URI[md5sum] = "c328993b68afe3e5bd87c8ea9bdeb028"
SRC_URI[sha256sum] = "134bfe122fd25599bb807bb8130e7ba6d9bdb851e0b16efcb83ac4f5d0b70057"

inherit autotools pkgconfig

