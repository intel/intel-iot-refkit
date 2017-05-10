FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# libnss-mdns is not supported, so remove it from the RRECOMMENDS
RRECOMMENDS_avahi-daemon_remove_libc-glibc_refkit-config = " libnss-mdns"
RRECOMMENDS_${PN}_remove_libc-glibc_refkit-config = " libnss-mdns"

# provide libdns_sd.so and dns_sd.h header
EXTRA_OECONF_append_refkit-config = "--enable-compat-libdns_sd"

FILES_${PN}_append_refkit-config = " \
    ${libdir}/libdns_sd.* \
"

# add firewall support
RDEPENDS_${PN}_append_refkit-firewall += " iptables"

SRC_URI_append_refkit-firewall = "\
    file://${PN}-ipv4.conf \
    file://${PN}-ipv6.conf \
"

do_install_append_refkit-config() {
    install -d ${D}${includedir}/avahi-compat-libdns_sd
    install -m 0644 ${S}/avahi-compat-libdns_sd/dns_sd.h ${D}${includedir}/avahi-compat-libdns_sd/

}
do_install_append_refkit-firewall() {
    install -d ${D}${systemd_unitdir}/system/avahi-daemon.socket.d
    install -m 0644 ${WORKDIR}/${PN}-ipv4.conf ${D}${systemd_unitdir}/system/avahi-daemon.socket.d
    if ${@bb.utils.contains('DISTRO_FEATURES', 'ipv6', 'true', 'false', d)}; then
        install -m 0644 ${WORKDIR}/${PN}-ipv6.conf ${D}${systemd_unitdir}/system/avahi-daemon.socket.d
    fi
}

FILES_${PN}_append_refkit-firewall = " \
    ${systemd_unitdir}/system/avahi-daemon.socket.d/${PN}-ipv4.conf \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ipv6', \
        '${systemd_unitdir}/system/avahi-daemon.socket.d/${PN}-ipv6.conf', '', d)} \
"
