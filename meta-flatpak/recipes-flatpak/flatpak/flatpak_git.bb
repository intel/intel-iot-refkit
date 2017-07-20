DESCRIPTION = "Versioned Application/Runtime Respository."
HOMEPAGE = "http://flatpak.org"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://COPYING;md5=4fbd65380cdd255951079008b364516c"

SRC_URI = " \
    gitsm://git@github.com/flatpak/flatpak;protocol=https \
    file://0001-autogen.sh-fall-back-to-no-gtkdocize-if-it-is-there-.patch \
    file://0002-common-Allow-command-to-include-command-line-options.patch \
    file://0003-lib-Allow-passing-command-line-argument-through-laun.patch \
"

SRCREV = "9a19ea7c1329d55129898330f5c329ece05c875e"

PV = "0.9.7+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig gettext requires-systemd gobject-introspection

DEPENDS = " \
    glib-2.0 json-glib libsoup-2.4 libarchive elfutils fuse \
    ostree libassuan libgpg-error bubblewrap systemd \
"

DEPENDS_class-native = " \
    glib-2.0-native libsoup-2.4-native json-glib-native libarchive-native \
    elfutils-native fuse-native ostree-native \
    libassuan-native libgpg-error-native bubblewrap-native \
"

RDEPENDS_${PN}_class-target = " \
    bubblewrap \
    ca-certificates \
"

AUTO_LIBNAME_PKGS = ""

# package configuration
PACKAGECONFIG ?= ""

PACKAGECONFIG[seccomp] = "--enable-seccomp,--disable-seccomp,seccomp"
PACKAGECONFIG[x11] = "--enable-xauth,--disable-xauth,x11"
PACKAGECONFIG[system-helper] = "--enable-system-helper,--disable-system-helper,poklit"

EXTRA_OECONF += " \
    --disable-docbook-docs \
    --disable-gtk-doc-html \
    --disable-documentation \
    --with-systemdsystemunitdir=${systemd_unitdir}/system \
"

# package content
PACKAGES =+ " \
    ${PN}-build \
    ${PN}-bash-completion \
    ${PN}-gdm \
"

FILES_${PN} += " \
    ${libdir}/systemd/user/*.service \
    ${libdir}/systemd/user/dbus.service.d/*.conf \
    ${libdir}/girepository-1.0 \
    ${datadir}/gir-1.0 \
    ${datadir}/dbus-1/services/*.service \
    ${datadir}/dbus-1/interfaces/*.xml \
"

FILES_${PN}-build = "${bindir}/flatpak-builder"

FILES_${PN}-bash-completion = " \
    ${sysconfdir}/profile.d/flatpak.sh \
    ${datadir}/bash-completion/completions/flatpak \
"

FILES_${PN}-gdm = " \
    ${datadir}/gdm/env.d/flatpak.env \
"

do_configure_prepend() {
    cd ${S}
    NOCONFIGURE=1 ./autogen.sh
    cd -
}

BBCLASSEXTEND = "native"
