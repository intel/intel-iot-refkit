FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

RDEPENDS_${PN}-sshd_append_refkit-firewall = " iptables"

SRC_URI_append_refkit-firewall = "\
    file://${PN}-ipv4.conf \
    file://${PN}-ipv6.conf \
"

do_install_append_refkit-firewall() {
    install -d ${D}${systemd_unitdir}/system/sshd.socket.d
    install -m 0644 ${WORKDIR}/${PN}-ipv4.conf ${D}${systemd_unitdir}/system/sshd.socket.d
    if ${@bb.utils.contains('DISTRO_FEATURES', 'ipv6', 'true', 'false', d)}; then
        install -m 0644 ${WORKDIR}/${PN}-ipv6.conf ${D}${systemd_unitdir}/system/sshd.socket.d
    fi
}

FILES_${PN}_append_refkit-firewall = " \
    ${systemd_unitdir}/system/sshd.socket.d/${PN}-ipv4.conf \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ipv6', \
        '${systemd_unitdir}/system/sshd.socket.d/${PN}-ipv6.conf', '', d)} \
"
