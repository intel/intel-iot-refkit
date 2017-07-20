DESCRIPTION = "Versioned Operating System Repository."
HOMEPAGE = "https://ostree.readthedocs.io"
LICENSE = "LGPLv2.1"

LIC_FILES_CHKSUM = "file://COPYING;md5=5f30f0716dfdd0d91eb439ebec522ec2"

SRC_URI = " \
    gitsm://git@github.com/ostreedev/ostree;protocol=https \
    file://0001-autogen.sh-fall-back-to-no-gtkdocize-if-it-is-there-.patch \
"

SRCREV = "5a5e465492aca13937dab7a2df39f25da94e6e36"

PV = "2017.8+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig requires-systemd gobject-introspection

DEPENDS = " \
    glib-2.0 libsoup-2.4 gpgme e2fsprogs \
    libcap fuse libarchive zlib xz \
    systemd \
"

DEPENDS_class-native = " \
    glib-2.0-native libsoup-2.4-native gpgme-native e2fsprogs-native \
    libcap-native fuse-native libarchive-native zlib-native xz-native \
"

RDEPENDS_${PN}_class-target = " \
    gnupg \
"

AUTO_LIBNAME_PKGS = ""

# package configuration
PACKAGECONFIG ??= ""

EXTRA_OECONF_class-target += "--disable-man"
EXTRA_OECONF_class-native += " \
    --disable-man \
    --with-builtin-grub2-mkconfig \
    --enable-wrpseudo-compat \
    --disable-otmpfile \
"

# package content
PACKAGES += "${PN}-systemd-generator"

FILES_${PN} += "${libdir}/girepository-1.0 ${datadir}/gir-1.0"
SYSTEMD_SERVICE_${PN} = "ostree-prepare-root.service ostree-remount.service"

FILES_${PN}-systemd-generator = "${libdir}/systemd/system-generators"

do_configure_prepend() {
    cd ${S}
    NOCONFIGURE=1 ./autogen.sh
    cd -
}

BBCLASSEXTEND = "native"
