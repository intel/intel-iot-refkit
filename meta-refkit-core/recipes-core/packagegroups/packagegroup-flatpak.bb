SUMMARY = "IoT Reference OS Kit Basic Flatpak Support"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = "\
    flatpak \
    flatpak-image-runtime \
"
