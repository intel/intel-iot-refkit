SUMMARY = "GLib wrapper around libusb1"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=2d5025d4aa3495befef8f17206a5b0a1"

DEPENDS = "glib-2.0 libusb"

SRC_URI = " \
    https://people.freedesktop.org/~hughsient/releases/libgusb-${PV}.tar.xz \
"
SRC_URI[sha256sum] = "5c0442f5e00792bea939bbd16df09245740ae0d8b6ad9890d09189e1f4a3a17a"

inherit autotools gettext pkgconfig gobject-introspection

