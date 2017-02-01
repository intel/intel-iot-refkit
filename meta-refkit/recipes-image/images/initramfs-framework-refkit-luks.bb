# This recipe creates a module for the initramfs-framework in OE-core
# which opens the partition identified via the root
# kernel parameter as a LUKS container and changes bootparam_root so
# that the following init code uses the decrypted volume.
#
# Currently a proof-of-concept with a fixed password, do not use in
# production!

SUMMARY = "LUKS module for the modular initramfs system"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
RDEPENDS_${PN} += "initramfs-framework-base"

SRC_URI = " \
    file://initramfs-framework-refkit-luks \
"

do_install () {
    install -d ${D}/init.d
    install ${WORKDIR}/initramfs-framework-refkit-luks  ${D}/init.d/80-luks
}

FILES_${PN} = "/init.d"
RDEPENDS_${PN} = "cryptsetup"
