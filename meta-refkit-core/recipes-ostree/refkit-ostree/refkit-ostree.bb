SUMMARY = "IoT RefKit ostree helper, scripts, services, et al."

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
  file://${PN} \
"

DEPENDS = "ostree"

inherit autotools pkgconfig systemd distro_features_check

REQUIRED_DISTRO_FEATURES = "ostree systemd"

S = "${WORKDIR}/${PN}"

PACKAGES += "${PN}-initramfs"

FILES_${PN}-initramfs = " \
    ${bindir}/refkit-ostree \
"

FILES_${PN} = " \
    ${bindir}/refkit-ostree-update \
    ${systemd_unitdir}/system/* \
    ${datadir}/${PN} \
"

# Our systemd services.
SYSTEMD_SERVICE_${PN} = " \
    refkit-patch-ostree-param.service \
    refkit-update.service \
    refkit-reboot.service \
    refkit-update-post-check.service \
"

EXTRA_OECONF += " \
            --with-systemdunitdir=${systemd_unitdir}/system \
"

RDEPENDS_${PN} += "ostree"
