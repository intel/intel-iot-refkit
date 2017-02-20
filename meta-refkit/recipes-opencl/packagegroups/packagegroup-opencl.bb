SUMMARY = "OpenCL package group"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    beignet-minnowmax \
    beignet-570x \
    ocl-icd \
"
