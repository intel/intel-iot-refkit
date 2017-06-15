FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# refkit.cfg disables CONFIG_SYSLOGD so the corresponding packaging
# needs to be dropped as well.
SYSTEMD_PACKAGES_df-refkit-config = ""
PACKAGES_remove_df-refkit-config = "${PN}-syslog"
RRECOMMENDS_${PN}_remove_df-refkit-config = "${PN}-syslog"

SRC_URI_append_df-refkit-config = "\
    file://refkit.cfg \
"
