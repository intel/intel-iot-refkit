SUMMARY = "OpenCL package group"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    beignet \
    ocl-icd \
"
