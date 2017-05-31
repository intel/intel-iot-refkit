SUMMARY = "Components for interfacing with sensors"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    mraa \
    mraa-utils \
    upm \
"
