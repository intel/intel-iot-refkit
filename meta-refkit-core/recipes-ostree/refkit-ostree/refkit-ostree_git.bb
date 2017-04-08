SUMMARY = "OSTree helper/wrapper scripts et al. for IoT RefKit."

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

# TODO: replace with more recent implementation in C,
# move code into intel-iot-refkit?
SRC_URI = " \
  git://git@github.com/klihub/refkit-ostree-upgrade.git;protocol=http;branch=master \
"

SRCREV = "a196e93ed90b65f21e496aa566d17b06484fcc45"

inherit autotools systemd distro_features_check

REQUIRED_DISTRO_FEATURES = "ostree systemd"

S = "${WORKDIR}/git"

FILES_${PN} = " \
    ${bindir}/refkit-ostree \
    ${systemd_unitdir}/system/* \
"

# We want the following services enabled.
SYSTEMD_SERVICE_${PN} = " \
    ostree-patch-proc-cmdline.service \
    ostree-update.service \
    ostree-post-update.service \
"

EXTRA_OECONF += " \
            --with-systemdunitdir=${systemd_unitdir} \
"

RDEPENDS_${PN} += "ostree"
