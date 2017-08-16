SUMMARY = "Protocol Buffers Python bindings"
SECTION = "devel/python"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=35953c752efc9299b184f91bef540095"

inherit setuptools3

SRCREV = "a6189acd18b00611c1dc7042299ad75486f08a1a"
PV = "3.3.0+git${SRCPV}"
SRC_URI = "git://github.com/google/protobuf.git"

S = "${WORKDIR}/git/python"

DEPENDS = "python3 protobuf protobuf-native python3-setuptools-native"
