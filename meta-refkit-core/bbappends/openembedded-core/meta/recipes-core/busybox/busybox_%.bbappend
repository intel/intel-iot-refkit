FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# refkit.cfg disables CONFIG_SYSLOGD so the corresponding packaging
# needs to be dropped as well.
SYSTEMD_PACKAGES_refkit-config = ""
PACKAGES_remove_refkit-config = "${PN}-syslog"
RRECOMMENDS_${PN}_remove_refkit-config = "${PN}-syslog"

SRC_URI_append_refkit-config = "\
    file://refkit.cfg \
"
