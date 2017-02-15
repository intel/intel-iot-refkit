LICENSE = "LGPLv2.1+"
LIC_FILES_CHKSUM = "file://COPYING;md5=6b566c5b4da35d474758324899cb4562"

SRC_URI = "git://anongit.freedesktop.org/beignet;nobranch=1 \
           file://fix-llvm-paths.patch \
           "
SRC_URI_append_class-native = " file://0001-reduced-native-for-1.2.1.patch"
SRC_URI_append_class-target = " file://0001-Run-native-gbe_bin_generater-to-compile-built-in-ker.patch"

BBCLASSEXTEND = "native"

# CMake cannot digest "+" in pathes -> replace it with dots.
PV = "1.2.1.${@ 'git${SRCPV}'.replace('+', '.')}"
SRCREV = "097365ed1a79cd03dc689b37b03552e455eb3854"
S = "${WORKDIR}/git"

PROVIDES += "virtual/opencl-headers virtual/opencl-headers-cxx"

DEPENDS = "beignet-native clang libdrm mesa"
DEPENDS_class-native = "clang-native"

# built-in kernels depend on libocl's headers (e.g. ocl_as.h) yet there is no
# dependency specified for that in beignet's build system. This causes race
# condition when libgbe.so is compiled for the target.
PARALLEL_MAKE = ""

inherit cmake pkgconfig

# There is no python in sysroot -> look for it on the build host.
# WARNING: remove CLang from the host otherwise it might get into use
#          instead of the one from meta-clang.
OECMAKE_FIND_ROOT_PATH_MODE_PROGRAM = "BOTH"

EXTRA_OECMAKE = " -DSTANDALONE_GBE_COMPILER_DIR=${STAGING_BINDIR_NATIVE} -DLLVM_LIBRARY_DIR=${STAGING_LIBDIR} -DGEN_PCI_ID=0x1A84"
EXTRA_OECMAKE_class-native = " -DBEIGNET_INSTALL_DIR=/usr/lib/beignet -DLLVM_LIBRARY_DIR=${STAGING_LIBDIR_NATIVE}"

# TODO respect distrofeatures for x11
PACKAGECONFIG ??= ""
PACKAGECONFIG[examples] = '-DBUILD_EXAMPLES=1,-DBUILD_EXAMPLES=0,libva'
# TODO: add explicit on/off upstream
PACKAGECONFIG[x11] = ",,libxext libxfixes"

FILES_${PN} += " \
                ${sysconfdir}/OpenCL/vendors/intel-beignet.icd \
                ${libdir} \
                ${libdir}/beignet/ \
                ${libdir}/beignet/* \
               "

do_install_append () {
    # Create intel-beignet.icd file
    mkdir -p ${D}${sysconfdir}/OpenCL/vendors/
    echo ${libdir}/beignet/libcl.so > ${D}${sysconfdir}/OpenCL/vendors/intel-beignet.icd
}

do_install_class-native() {
    install -d ${D}${libdir}/cmake
    install -m644 ${S}/CMake/FindStandaloneGbeCompiler.cmake ${D}${libdir}/cmake

    install -d ${D}${bindir}
    install ${B}/backend/src/gbe_bin_generater ${D}${bindir}
    install ${B}/backend/src/libgbe.so ${D}${libdir}

    install -d ${D}${bindir}/include
    install ${B}/backend/src/libocl/usr/lib/beignet/include/* ${D}${bindir}/include
    install ${B}/backend/src/libocl/usr/lib/beignet/beignet.bc ${D}${bindir}/
}
