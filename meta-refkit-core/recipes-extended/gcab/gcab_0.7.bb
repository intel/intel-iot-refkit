SUMMARY = "Microsoft Cabinet file manipulation library"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=4fbd65380cdd255951079008b364516c"

DEPENDS = "glib-2.0 glib-2.0-native intltool-native"

SRC_URI = " \
    http://ftp.gnome.org/pub/GNOME/sources/gcab/${PV}/gcab-${PV}.tar.xz \
"
SRC_URI[sha256sum] = "a16e5ef88f1c547c6c8c05962f684ec127e078d302549f3dfd2291e167d4adef"

inherit autotools gettext gobject-introspection

BBCLASSEXTEND = "native nativesdk"
