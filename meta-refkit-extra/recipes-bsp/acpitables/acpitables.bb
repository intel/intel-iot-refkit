SUMMARY = "acpi tables for Intel 570x buttons and leds"
DESCRIPTION = "This recipe injects acpi tables for Intel 570x buttons and leds"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${META_REFKIT_BASE}/COPYING.MIT;md5=838c366f69b72c5df05c96dff79b35f2"

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI = "\
        file://buttons.asl \
        file://leds.asl \
"

DEPENDS = "acpica-native"

inherit deploy

do_compile() {
        rm -fr ${WORKDIR}/acpi-tables/kernel
        install -d ${WORKDIR}/acpi-tables/kernel/firmware/acpi

        iasl -p ${WORKDIR}/acpi-tables/kernel/firmware/acpi/buttons.asl ${WORKDIR}/buttons.asl
        iasl -p ${WORKDIR}/acpi-tables/kernel/firmware/acpi/leds.asl ${WORKDIR}/leds.asl
}

do_deploy() {
        cd ${WORKDIR}/acpi-tables
        find kernel | cpio -H newc -o > ${DEPLOYDIR}/acpi-tables.cpio
}

addtask deploy before do_build after do_compile
