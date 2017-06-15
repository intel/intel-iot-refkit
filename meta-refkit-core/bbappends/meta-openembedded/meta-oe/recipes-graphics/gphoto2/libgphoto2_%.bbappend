# usbutils depends directly on libusb1, not the obsolete compatibility. This removes dependency on libusb-compat.
DEPENDS_remove_df-refkit-config = "virtual/libusb0"
DEPENDS_append_df-refkit-config = " libusb1"
