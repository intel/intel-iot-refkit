FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

EXTRA_OECMAKE_df-refkit-computervision = " \
       -DBUILD_SHARED_LIBS:BOOL=ON -DBUILD_UNIT_TESTS:BOOL=OFF -DBUILD_EXAMPLES:BOOL=ON \
       -DBUILD_GRAPHICAL_EXAMPLES:BOOL=${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', 'ON', 'OFF', d)} \
"
 
PACKAGES_df-refkit-computervision = "${PN} ${PN}-dbg ${PN}-dev ${PN}-examples ${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', '${PN}-graphical-examples', '', d)}"

SRC_URI_append_df-refkit-computervision = " \
    file://0001-scripts-removed-bashisms.patch \
    file://0001-examples-control-building-of-the-graphical-examples.patch \
    file://0001-Add-missing-includes-for-functional.patch \
"

RDEPENDS_${PN}_remove_df-refkit-computervision = "bash"
