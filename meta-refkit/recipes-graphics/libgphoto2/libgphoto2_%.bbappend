# usbutils depends directly on libusb1, not the obsolete compatibility. This removes dependency on libusb-compat.
DEPENDS_remove = "virtual/libusb0"
DEPENDS_append = " libusb1"
