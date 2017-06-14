DESCRIPTION = "ROS-Industrial support for the uArm Metal"
SECTION = "devel"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://package.xml;beginline=11;endline=11;md5=d566ef916e9dedc494f5f793a6690ba5"

SRC_URI = "file://${PN}-${PV}/config/joint_names.yaml \
           file://${PN}-${PV}/launch/refkit-uarm.launch \
           file://${PN}-${PV}/launch/robot_interface_streaming.launch \
           file://${PN}-${PV}/urdf/model.urdf \
           file://${PN}-${PV}/CMakeLists.txt \
           file://${PN}-${PV}/package.xml \
          "

inherit catkin

RDEPENDS_${PN} = "industrial-robot-client"
