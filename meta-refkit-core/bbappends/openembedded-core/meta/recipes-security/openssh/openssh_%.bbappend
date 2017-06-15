FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

RDEPENDS_${PN}-sshd_append_df-refkit-firewall = " nftables"

SRC_URI_append_df-refkit-firewall = "\
    file://openssh-sshd.ruleset \
"

do_install_append_df-refkit-firewall() {
    install -d ${D}${libdir}/firewall/services
    install -m 0644 ${WORKDIR}/openssh-sshd.ruleset ${D}${libdir}/firewall/services/
}

FILES_${PN}_append_df-refkit-firewall = " \
    ${libdir}/firewall/services/openssh-sshd.ruleset \
"
