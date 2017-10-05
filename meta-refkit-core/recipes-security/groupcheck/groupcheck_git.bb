# Copyright (C) 2016 Intel Corporation.
# Released under the MIT license (see COPYING.MIT for the terms)

DESCRIPTION = "Groupcheck -- a minimal polkit replacement"
HOMEPAGE = "http://github.com/ostroproject/groupcheck"
LICENSE = "LGPL2.1"
LIC_FILES_CHKSUM = "file://COPYING;md5=4fbd65380cdd255951079008b364516c"

SRC_URI = "git://github.com/ostroproject/groupcheck.git;protocol=git"
SRCREV = "3a6c336c1bdcd77ea040cdbf86cf1624af657cea"
PV = "2.0"

DEPENDS = "systemd"

S = "${WORKDIR}/git"

inherit autotools systemd pkgconfig distro_features_check
REQUIRED_DISTRO_FEATURES = "systemd"


do_install_append() {
    install -d ${D}${systemd_unitdir}/system
    install -d ${D}${sysconfdir}/dbus-1/system.d
    install -d ${D}${libdir}/sysusers.d

    # We start groupcheck so that it reads policy files from
    # ${datadir}/groupcheck.d/*.policy. Therefore here we inject
    # -d and remove the -f option.
    install -m 0644 ${S}/groupcheck.service ${D}${systemd_unitdir}/system/
    sed -i -e 's;^\(ExecStart=[^ ]*groupcheck\);\1 -d ${datadir}/groupcheck.d;' \
           -e 's;^\(ExecStart=[^ ]*groupcheck.*\)-f *[^ ]*;\1;' \
            ${D}${systemd_unitdir}/system/groupcheck.service
    install -d ${D}${datadir}/groupcheck.d

    install -m 0644 ${S}/org.freedesktop.PolicyKit1.conf ${D}${sysconfdir}/dbus-1/system.d/
    install -m 0644 ${S}/groupcheck.conf ${D}${libdir}/sysusers.d/
}

FILES_${PN} += " \
    ${libdir}/sysusers.d/groupcheck.conf \
    ${datadir}/groupcheck.d \
"

SYSTEMD_SERVICE_${PN} = "groupcheck.service"
