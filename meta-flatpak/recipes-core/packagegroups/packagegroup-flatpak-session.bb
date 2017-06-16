SUMMARY = "IoT Reference OS Kit Basic Flatpak Session/Application Support"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = "\
    packagegroup-flatpak \
    flatpak-utils \
    flatpak-predefined-repos \
"
