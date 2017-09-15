SUMMARY = "Updating Firmware in Linux"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

DEPENDS = "libgudev glib-2.0 polkit appstream-glib libgusb gcab-native intltool-native gettext-native"

SRC_URI = "git://github.com/hughsie/fwupd;method=https \
           file://meson-skip-test-directories-when-disabled.patch \
           "
SRCREV = "de3507d9c09f287570ff2de6c6c00b8c181a9f2f"
S = "${WORKDIR}/git"

# Introspection not working the way how meson does it (ends up calling the host ld).
EXTRA_OEMESON += "-Denable-introspection=false"

# Beware, some of the disabled features have dependencies for which
# there are no recipes.
#
# gpg is needed to verify content downloaded from the LVFS. It can be
# disabled safely when firmware only gets delivered via the local filesystem.
PACKAGECONFIG ?= "${@ bb.utils.filter('DISTRO_FEATURES', 'systemd', d) } uefi libelf gpg"
PACKAGECONFIG[colorhug] = "-Denable-colorhug=true,-Denable-colorhug=false,colorhug"
PACKAGECONFIG[consolekit] = "-Denable-consolekit=true,-Denable-consolekit=false,consolekit"
PACKAGECONFIG[doc] = "-Denable-doc=true,-Denable-doc=false,gtkdoc-native"
PACKAGECONFIG[dell] = "-Denable-dell=true,-Denable-dell=false,libsmbios_c"
PACKAGECONFIG[libelf] = "-Denable-libelf=true,-Denable-libelf=false,elfutils"
PACKAGECONFIG[man] = "-Denable-man=true,-Denable-man=false,docbook2man"
PACKAGECONFIG[systemd] = "-Denable-systemd=true,-Denable-systemd=false,systemd"
PACKAGECONFIG[thunderbolt] = "-Denable-thunderbolt=true,-Denable-thunderbolt=false,libtbtfwu"
PACKAGECONFIG[uefi-labels] = "-Denable-uefi-labels=true,-Denable-uefi-labels=false,cairo fontconfig"
PACKAGECONFIG[uefi] = "-Denable-uefi=true,-Denable-uefi=false,fwupdate,fwupdate"
# synaptics depends on dell
PACKAGECONFIG[synaptics] = "-Denable-synaptics=true,-Denable-synaptics=false"
PACKAGECONFIG[tests] = "-Denable-tests=true,-Denable-tests=false"
PACKAGECONFIG[gpg] = "-Denable-gpg=true,-Denable-gpg=false,gpgme"
PACKAGECONFIG[pkcs7] = "-Denable-pkcs7=true,-Denable-pkcs7=false,gnutls"

inherit check-available
inherit ${@ check_available_class(d, 'meson', ${HAVE_MESON}) }

do_install_append () {
    rm -rf ${D}/${datadir}/installed-tests
}

# Support groupcheck instead of polkit?
do_install_append_df-refkit-groupcheck () {
    # Instead of hard-coding actions, we take them from the polkit configuration.
    install -d ${D}${datadir}/groupcheck.d
    for action in `grep action.id ${D}${datadir}/polkit-1/*/*.policy | sed -e 's/.*"\(.*\)".*/\1/' | sort -u`; do
        # Just a sanity check that we really picked something that looks like an action.
        case $action in org.freedesktop.fwupd.*)
            # "adm" gets added as auxiliary group for root in base-passwd_%.bbappend.
            # We rely on that here to grant also root processes access to fwupd.
            echo $action='"adm"' >>${D}${datadir}/groupcheck.d/org.freedesktop.fwupd.policy;;
        esac
    done
    chmod 0666 ${D}${datadir}/groupcheck.d/org.freedesktop.fwupd.policy

    rm -rf ${D}${datadir}/polkit-1/
}

FILES_${PN} += " \
    ${systemd_system_unitdir} \
    ${datadir}/metainfo \
    ${datadir}/app-info \
    ${datadir}/dbus-1 \
    ${datadir}/polkit-1 \
    ${libdir}/fwupd-plugins-2 \
    ${datadir}/groupcheck.d \
"

# We are explicit about packaging config files because we want
# full control over which data sources are trusted.
FILES_${PN}_remove = "${sysconfdir}"
FILES_${PN} += " \
    ${sysconfdir}/fwupd/ \
    ${sysconfdir}/fwupd.conf \
    ${sysconfdir}/dbus-1/system.d/org.freedesktop.fwupd.conf \
"

# The /etc/pki/fwupd directory is used to verify whether firmware
# files are trusted. The /etc/pki/fwupd-metadata does the same for
# metadata .xml files. Upstream fwupd already provides public
# keys that are needed for LVFS.
PACKAGES =+ "${PN}-pki"
FILES_${PN}-pki = " \
    ${sysconfdir}/pki/ \
"
RDEPENDS_${PN}-pki = "gnupg"

# Configuration for the Linux Vendor Firmware Service.
# Currently that is the only piece which has a hard dependency
# on GnuPG because the GnuPG signature is checked before trusting
# downloaded files, therefore we package it separately and set
# the dependeny.
#
# Without it, fwupd can still be used with firmware files provided
# differently, for example by using the "vendor" provider and
# add the firmware directly to the rootfs.
PACKAGES =+ "${PN}-lvfs"
FILES_${PN}-lvfs = " \
    ${sysconfdir}/fwupd/remotes.d/lvfs.conf \
    ${sysconfdir}/fwupd/remotes.d/lvfs-testing.conf \
"
RDEPENDS_${PN}-lvfs += "${PN}-pki"

# An example remote which is not needed for production.
PACKAGES =+ "${PN}-demo-vendor"
FILES_${PN}-demo-vendor = " \
    ${sysconfdir}/fwupd/remotes.d/vendor.conf \
    ${datadir}/fwupd/remotes.d/vendor/ \
"
