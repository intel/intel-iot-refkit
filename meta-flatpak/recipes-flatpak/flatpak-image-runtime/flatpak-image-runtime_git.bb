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

SRCREV = "d4cc5bbbe8be1a1cef4eecb1df656e60d8ad18de"

DEPENDS = "systemd"

inherit autotools pkgconfig requires-systemd flatpak-config

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
            --with-arch=${FLATPAK_ARCH} \
            --with-branch=${FLATPAK_BRANCH} \
"

do_configure_prepend () {
    cd ${S}
        NOCONFIGURE=1 ./bootstrap
    cd -
}

