FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

EXTRA_OECMAKE = " \
       -DBUILD_SHARED_LIBS:BOOL=ON -DBUILD_UNIT_TESTS:BOOL=OFF -DBUILD_EXAMPLES:BOOL=ON \
       -DBUILD_GRAPHICAL_EXAMPLES:BOOL=${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', 'ON', 'OFF', d)} \
"
 
PACKAGES = "${PN} ${PN}-dbg ${PN}-dev ${PN}-examples ${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', '${PN}-graphical-examples', '', d)}"

SRC_URI_append = " \
    file://0001-scripts-removed-bashisms.patch \
    file://0001-examples-control-building-of-the-graphical-examples.patch \
"

RDEPENDS_${PN}_remove = "bash"
