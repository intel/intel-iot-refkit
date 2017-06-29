SUMMARY = "initramfs module for OSTree-enabled images which bind-mounts the rootfs directory tree"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI += " \
    file://ostree \
"

inherit distro_features_check
REQUIRED_DISTRO_FEATURES = "ostree"

do_install () {
    install -D -m 0755 ${WORKDIR}/ostree ${D}/init.d/91-ostree
}

FILES_${PN} = "/init.d/91-ostree"
