SUMMARY = "Components for computer vision profile"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    opencv \
    gstreamer1.0-vaapi \
    gstreamer1.0-plugins-good \
    libva-intel-driver \
    librealsense \
    packagegroup-opencl \
"
