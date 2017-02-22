LICENSE = "KhronosFreeUse"
LIC_FILES_CHKSUM = "file://cl.h;beginline=1;endline=27;md5=b75d70d0f7cb3bb2bc8886141a84319e"

SRC_URI = "git://github.com/KhronosGroup/OpenCL-Headers;branch=opencl12"
SRCREV = "47be6196cb09f2718990f9537ac69fc5ec43aed5"

S = "${WORKDIR}/git"

PROVIDES += "virtual/opencl-headers"

RDEPENDS_${PN}-dev = ""

do_install() {
    mkdir -p ${D}${includedir}/CL
    install -m644 *.h ${D}${includedir}/CL
}
