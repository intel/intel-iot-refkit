LICENSE = "BSD-2-Clause"
LIC_FILES_CHKSUM = "file://COPYING;md5=232257bbf7320320725ca9529d3782ab"

SRC_URI = "https://forge.imag.fr/frs/download.php/716/${BP}.tar.gz"
SRC_URI[md5sum] = "7dab1a9531ea79c19a414a9ee229504e"
SRC_URI[sha256sum] = "0c8ac13e2c5b737c34de49f9aca6cad3c4d33dd0bbb149b01238d76e798feae5"

inherit autotools

DEPENDS += "ruby-native"

BBCLASSEXTEND = "native"
