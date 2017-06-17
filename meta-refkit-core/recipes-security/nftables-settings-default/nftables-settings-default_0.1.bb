# Copyright (C) 2017 Intel.
# Released under the MIT license (see COPYING.MIT for the terms)

DESCRIPTION = "Default nftables configuration."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

RDEPENDS_${PN} = "python3 python3-re python3-fcntl"

SRC_URI = " \
    file://firewall-update.py \
    file://zones.config \
    file://zones.template \
    file://firewall.template \
    file://firewall.conf \
    file://99-network-device.rules \
    file://firewall.service \
    file://firewall-config.path \
    file://firewall-config.service \
    file://firewall-config-update.service \
    file://firewall-zones-update.service \
    file://firewall.path \
    file://network-device-event@.service \
    file://variables.ruleset \
"

do_install() {
    install -d ${D}${base_libdir}/udev/rules.d
    install -d ${D}${libdir}/tmpfiles.d
    install -d ${D}${libdir}/firewall/services
    install -d ${D}${bindir}
    install -d ${D}${systemd_unitdir}/system/

    install -m 0644 ${WORKDIR}/*.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/*.path ${D}${systemd_unitdir}/system/
    install -m 0755 ${WORKDIR}/firewall-update.py ${D}${bindir}/
    install -m 0644 ${WORKDIR}/zones.config ${D}${libdir}/firewall/
    install -m 0644 ${WORKDIR}/*.template ${D}${libdir}/firewall/
    install -m 0644 ${WORKDIR}/variables.ruleset ${D}${libdir}/firewall/
    install -m 0644 ${WORKDIR}/99-network-device.rules ${D}${base_libdir}/udev/rules.d/
    install -m 0644 ${WORKDIR}/firewall.conf ${D}${libdir}/tmpfiles.d/
}

FILES_${PN} = " \
    ${base_libdir}/udev/rules.d \
    ${libdir}/tmpfiles.d \
    ${libdir}/firewall/services \
    ${libdir}/firewall/* \
    ${bindir}/* \
    ${systemd_unitdir}/system/* \
"

SYSTEMD_SERVICE_${PN} = " \
    firewall.service \
    firewall.path \
"
