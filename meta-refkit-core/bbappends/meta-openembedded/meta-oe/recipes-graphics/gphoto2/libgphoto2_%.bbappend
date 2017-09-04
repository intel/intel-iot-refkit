# usbutils depends directly on libusb1, not the obsolete compatibility. This removes dependency on libusb-compat.
DEPENDS_remove_df-refkit-config = "virtual/libusb0"
DEPENDS_append_df-refkit-config = " libusb1"

# OE-Core gettext.bbclass dropped the dependency to virtual/gettext
# but libgphoto2 recipe expects to find gettext files in STAGING_DATADIR.
# The better fix would be to look for those files in the _NATIVE
# counterpart. In the mean time, add the direct dependency to gettext to
# ensure the needed file(s) are found in STAGING_DATADIR.
DEPENDS_append_df-refkit-config = " gettext"
