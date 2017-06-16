SUMMARY = "IoT Reference OS Kit Industrial Robotics profile package groups"
LICENSE = "MIT"
PR = "r1"

inherit packagegroup

SUMMARY_${PN} = "IoT Reference OS Kit Industrial Robotics profile"
RDEPENDS_${PN} = "\
    roslaunch \
    industrial-trajectory-filters \
    industrial-robot-simulator \
    industrial-robot-client \
    industrial-utils \
    "
