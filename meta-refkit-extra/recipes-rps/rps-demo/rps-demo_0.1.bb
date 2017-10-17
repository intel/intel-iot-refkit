# Copyright (C) 2017 Christian da Costa <christian.da.costa@intel.com>

SUMMARY = "Rock Paper Scissors - demo powered by computer vision"
DESCRIPTION = "A showcase demo of the classic rock paper scissors game. It uses a realsense camera and haar cascade classifiers for video recognition"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${WORKDIR}/LICENSE;md5=4889fee2c86b3b6ba5040a377e92b2cf"

DEPENDS = " \
    librealsense \
    opencv \
    gtk+3 \
"

inherit meson

SRC_URI = "file://rps_demo.tar.gz"

S = "${WORKDIR}/src/"
