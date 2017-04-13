# libusb is not required. This removes dependency on libusb-compat.
DEPENDS_remove = "libusb"

# split bluetoothctl into a subpackage
PACKAGES =+ "${PN}-client"
FILES_${PN}-client = "${@bb.utils.contains('PACKAGECONFIG', 'readline', '${bindir}/bluetoothctl', '', d)}"
RRECOMMENDS_${PN} += "${PN}-client"
