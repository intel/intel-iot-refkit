SUMMARY = "IoT Reference OS Kit Connectivity package groups"
LICENSE = "MIT"
PR = "r1"

inherit packagegroup

SUMMARY_${PN} = "IoT Reference OS Kit Connectivity stack"
RDEPENDS_${PN} = "\
    bluez5 \
    bluez5-obex \
    connman \
    "
