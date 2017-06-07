FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

RDEPENDS_${PN}-sshd_append_refkit-firewall = " nftables"

SRC_URI_append_refkit-firewall = "\
    file://openssh-sshd.ruleset \
"

do_install_append_refkit-firewall() {
    install -d ${D}${libdir}/firewall/services
    install -m 0644 ${WORKDIR}/openssh-sshd.ruleset ${D}${libdir}/firewall/services/
}

FILES_${PN}_append_refkit-firewall = " \
    ${libdir}/firewall/services/openssh-sshd.ruleset \
"
