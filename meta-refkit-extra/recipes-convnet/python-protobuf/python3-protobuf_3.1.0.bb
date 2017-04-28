SUMMARY = "Protocol Buffers Python bindings"
SECTION = "devel/python"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=35953c752efc9299b184f91bef540095"

inherit setuptools3

SRCREV = "a428e42072765993ff674fda72863c9f1aa2d268"
PV = "3.1.0+git${SRCPV}"
SRC_URI = "git://github.com/google/protobuf.git"

S = "${WORKDIR}/git/python"

DEPENDS = "python3 protobuf protobuf-native python3-setuptools-native"
