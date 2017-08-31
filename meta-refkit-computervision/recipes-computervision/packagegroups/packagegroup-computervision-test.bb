SUMMARY = "Components for computer vision profile testing and interactive use"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    libva-utils \
    opencv-samples \
    python3-opencv \
    librealsense-examples \
    viennacl-examples \
    caffe-bvlc-reference \
"
