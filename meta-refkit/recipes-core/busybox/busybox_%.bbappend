FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# refkit.cfg disables CONFIG_SYSLOGD so the corresponding packaging
# needs to be dropped as well.
SYSTEMD_PACKAGES = ""
PACKAGES_remove = "${PN}-syslog"
RRECOMMENDS_${PN}_remove = "${PN}-syslog"

SRC_URI_append = "\
    file://refkit.cfg \
"

RPROVIDES_${PN} += "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '/bin/sh', '', d)}"
