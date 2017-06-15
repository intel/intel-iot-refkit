SUMMARY = "A systemd service to set up a fake flatpak runtime for the image."
DESCRIPTION = "This package provides a systemd service that fakes a flatpak \
runtime for the currently running image, using read-only bind mounts."
HOMEPAGE = "https://github.com/klihub/flatpak-image-runtime"
SECTION = "misc"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
  git://git@github.com/klihub/flatpak-image-runtime.git;protocol=http;branch=master \
"

SRCREV = "8f563cfcc07a9f9d7cdcf0319cffda6d23745303"

DEPENDS = "systemd"

inherit autotools pkgconfig required-systemd flatpak-config

S = "${WORKDIR}/git"

FILES_${PN} = " \
    ${datadir}/flatpak-image-runtime \
    ${systemd_unitdir}/system/flatpak-image-runtime.service \
"

SYSTEMD_SERVICE_${PN} = " \
    flatpak-image-runtime.service \
"

EXTRA_OECONF += " \
            --with-systemdunitdir=${systemd_unitdir} \
            --with-domain=${FLATPAK_DOMAIN} \
            --with-arch=${MACHINE} \
            --with-branch=${FLATPAK_BRANCH} \
"

do_configure_prepend () {
    cd ${S}
        NOCONFIGURE=1 ./bootstrap
    cd -
}

