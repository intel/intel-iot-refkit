DESCRIPTION = "swupd plugin for updating the kernel+initramfs combo in the EFI system partition"
PV = "1.0"
LICENSE = "MIT"
DEPENDS = "glib-2.0"

SRC_URI = " \
    file://efi_combo_updater.c \
    file://efi-combo-trigger.service \
"
LIC_FILES_CHKSUM = "file://${WORKDIR}/efi_combo_updater.c;beginline=6;endline=6;md5=91a396ce9e1d88ba05f7f61134351413"

inherit systemd pkgconfig

RDEPENDS_${PN} += "gptfdisk"

# Add our efi-combo-trigger.
SYSTEMD_SERVICE_${PN} += "efi-combo-trigger.service"
# And activate it.
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

do_compile() {
    ${CC} ${LDFLAGS} ${WORKDIR}/efi_combo_updater.c  -Os -o ${B}/efi_combo_updater `pkg-config --cflags --libs glib-2.0`
}

do_install_append () {
    install -d ${D}/usr/bin
    install ${B}/efi_combo_updater ${D}/usr/bin/
    install -d ${D}/${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/efi-combo-trigger.service ${D}/${systemd_system_unitdir}
}
