# libusb is not required. This removes dependency on libusb-compat.
DEPENDS_remove_refkit-config = "libusb"

# split bluetoothctl into a subpackage
PACKAGES_prepend_refkit-config = "${PN}-client "
FILES_${PN}-client = "${@bb.utils.contains('PACKAGECONFIG', 'readline', '${bindir}/bluetoothctl', '', d)}"
RRECOMMENDS_${PN}_append_refkit-config += "${PN}-client"
