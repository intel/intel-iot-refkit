DESCRIPTION = "Test ROS nodes for Refkit"
SECTION = "devel"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://package.xml;beginline=11;endline=11;md5=58e54c03ca7f821dd3967e2a2cd1596e"

SRC_URI = "file://${PN}-${PV}/scripts/talker.py \
           file://${PN}-${PV}/scripts/listener.py \
           file://${PN}-${PV}/launch/helloworld.launch \
           file://${PN}-${PV}/CMakeLists.txt \
           file://${PN}-${PV}/package.xml \
          "

inherit catkin