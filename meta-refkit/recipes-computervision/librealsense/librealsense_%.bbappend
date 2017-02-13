DEPENDS = "libusb1 ${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', 'libpng libglu glfw', '', d)}"

EXTRA_OECMAKE = " \
       -DBUILD_SHARED_LIBS:BOOL=ON -DBUILD_UNIT_TESTS:BOOL=OFF \
       -DBUILD_EXAMPLES:BOOL=${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', 'ON', 'OFF', d)} \
"
 
PACKAGES = "${PN} ${PN}-dbg ${PN}-dev ${@bb.utils.contains('DISTRO_FEATURES', 'x11 opengl', '${PN}-examples ${PN}-graphical-examples', '', d)}"

