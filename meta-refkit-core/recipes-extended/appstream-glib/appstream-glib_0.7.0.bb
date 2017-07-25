SUMMARY = "GObjects and helper methods to make it easy to read and write AppStream metadata"
LICENSE = "LGPLv2"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=4fbd65380cdd255951079008b364516c"

DEPENDS = "glib-2.0 libarchive libsoup-2.4 gdk-pixbuf json-glib libyaml gperf-native glib-2.0-native gcab"

# depends on gtk+3 (expensive) and gcab (no recipe at the moment)
EXTRA_OEMESON += "-Denable-builder=false"

# No recipe at the moment.
EXTRA_OEMESON += "-Denable-stemmer=false"

# Introspection not working the way how meson does it (ends up calling the host ld).
EXTRA_OEMESON += "-Denable-introspection=false"

SRC_URI = "https://people.freedesktop.org/~hughsient/appstream-glib/releases/appstream-glib-${PV}.tar.xz \
           file://meson-introspection-optional.patch \
           file://meson-avoid-unnecessary-gdk-dependency.patch \
           "
SRC_URI[sha256sum] = "08c3655a54af958263800f1f4a5ef4e6a1da4e6db2432006b1ea07b94f4bc106"

inherit check-available
inherit ${@ check_available_class(d, 'meson', ${HAVE_MESON}) }

do_install_append () {
    rm -rf ${D}/${datadir}/gettext ${D}/${datadir}/installed-tests
}

PACKAGES += "${PN}-bash-completion"
FILES_${PN}-bash-completion += "${datadir}/bash-completion/completions/"

# Without it, parsing XML files fails (https://github.com/hughsie/fwupd/issues/38).
RDEPENDS_${PN} += "shared-mime-info"
