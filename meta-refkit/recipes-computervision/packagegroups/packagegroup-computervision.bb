SUMMARY = "Components for computer vision profile"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    opencv \
    gstreamer1.0-vaapi \
"
