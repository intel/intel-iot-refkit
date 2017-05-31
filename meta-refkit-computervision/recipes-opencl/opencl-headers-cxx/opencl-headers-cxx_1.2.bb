LICENSE = "KhronosFreeUse"
LIC_FILES_CHKSUM = "file://input_cl.hpp;beginline=1;endline=27;md5=ce1046da63d60ff91438a9c2392e0cc8"

SRC_URI = "git://github.com/KhronosGroup/OpenCL-CLHPP;branch=opencl21"
SRCREV = "d54d52ce6ab6301e821098c1176cb512686e3dbc"

S = "${WORKDIR}/git"

RDEPENDS_${PN}-dev = ""

PACKAGES = "${PN}"

PROVIDES += "virtual/opencl-headers-cxx"

do_compile() {
    python ${WORKDIR}/git/gen_cl_hpp.py
}

do_install() {
    mkdir -p ${D}${includedir}/CL
    install -m644 cl.hpp ${D}${includedir}/CL
}

FILES_${PN} = "${includedir}/CL/cl.hpp"
