LICENSE = "BSD-2-Clause"
LIC_FILES_CHKSUM = "file://COPYING;md5=232257bbf7320320725ca9529d3782ab"

SRC_URI = "https://forge.imag.fr/frs/download.php/814/${BP}.tar.gz"
SRC_URI[md5sum] = "32335dc7dd3ea2a4b994ca87f2f80554"
SRC_URI[sha256sum] = "02fa41da98ae2807e92742196831d320e3fc2f4cb1118d0061d9f51dda867730"

inherit autotools

DEPENDS += "ruby-native"

BBCLASSEXTEND = "native"

PROVIDES = "virtual/opencl-icd"
