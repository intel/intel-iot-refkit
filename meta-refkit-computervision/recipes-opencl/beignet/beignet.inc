LICENSE = "LGPLv2.1+"
LIC_FILES_CHKSUM = "file://COPYING;md5=6b566c5b4da35d474758324899cb4562"

SRC_URI = "git://anongit.freedesktop.org/beignet;nobranch=1 \
           file://fix-llvm-paths.patch \
           file://0001-api-mark-platform-not-supported-if-device-is-not-fou.patch \
           "
SRC_URI_append_class-native = " file://0001-reduced-native-for-1.3.1.patch"
SRC_URI_append_class-target = " file://0001-Run-native-gbe_bin_generater-to-compile-built-in-ker.patch"

BBCLASSEXTEND = "native"

# CMake cannot digest "+" in pathes -> replace it with dots.
PV = "1.3.1.${@ 'git${SRCPV}'.replace('+', '.')}"
SRCREV = "beaf26ff429bd8660d2103fb682243efeb828ab1"
S = "${WORKDIR}/git"

# we need to depend on ocl-icd, so that the exported symbols go right
DEPENDS = "${PN}-native clang libdrm mesa ocl-icd ncurses"
DEPENDS_class-native = "clang-native"

# To solve the PCI_ID problem, we use the target from filename for
# installing the library.

CL_HW_TARGET ?= "${@d.getVar('PN').split('-')[1]}"

# built-in kernels depend on libocl's headers (e.g. ocl_as.h) yet there is no
# dependency specified for that in beignet's build system. This causes race
# condition when libgbe.so is compiled for the target.
PARALLEL_MAKE = ""

inherit cmake pkgconfig

# There is no python in sysroot -> look for it on the build host.
# WARNING: remove CLang from the host otherwise it might get into use
#          instead of the one from meta-clang.
OECMAKE_FIND_ROOT_PATH_MODE_PROGRAM = "BOTH"

EXTRA_OECMAKE = " -DSTANDALONE_GBE_COMPILER_DIR=${STAGING_BINDIR_NATIVE} -DLLVM_LIBRARY_DIR=${STAGING_LIBDIR} -DBEIGNET_INSTALL_DIR=${libdir}/beignet-${CL_HW_TARGET}"
EXTRA_OECMAKE_class-native = " -DBEIGNET_INSTALL_DIR=/usr/lib/beignet -DLLVM_LIBRARY_DIR=${STAGING_LIBDIR_NATIVE}"

# TODO respect distrofeatures for x11
PACKAGECONFIG ??= ""
PACKAGECONFIG[examples] = '-DBUILD_EXAMPLES=1,-DBUILD_EXAMPLES=0,libva'
# TODO: add explicit on/off upstream
PACKAGECONFIG[x11] = ",,libxext libxfixes"

FILES_${PN} += " \
                ${sysconfdir}/OpenCL/vendors/intel-beignet-${CL_HW_TARGET}.icd \
                ${libdir} \
                ${libdir}/beignet-${CL_HW_TARGET}/ \
                ${libdir}/beignet-${CL_HW_TARGET}/* \
               "

do_install_append_class-target () {
    # Change the intel-beignet.icd file
    rm ${D}${sysconfdir}/OpenCL/vendors/intel-beignet.icd
    echo ${libdir}/beignet-${CL_HW_TARGET}/libcl.so > ${D}${sysconfdir}/OpenCL/vendors/intel-beignet-${CL_HW_TARGET}.icd

    # Remove AppStream metadata so that the packages won't conflict
    rm ${D}${datadir}/metainfo/com.intel.beignet.metainfo.xml
    rmdir --ignore-fail-on-non-empty -p ${D}${datadir}/metainfo
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
