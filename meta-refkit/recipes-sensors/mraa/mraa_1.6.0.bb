SUMMARY = "Low Level Skeleton Library for Communication on Intel platforms"
SECTION = "libs"
AUTHOR = "Brendan Le Foll, Tom Ingleby, Dmitry Rozhkov"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://COPYING;md5=66493d54e65bfc12c7983ff2e884f37f"

SRC_URI = "git://github.com/intel-iot-devkit/mraa.git;protocol=http;tag=v${PV} \
           "

S = "${WORKDIR}/git"

inherit cmake distutils-base

DEPENDS += "json-c"

EXTRA_OECMAKE_append = " -DINSTALLTOOLS:BOOL=ON -DFIRMATA=ON -DCMAKE_SKIP_RPATH=ON"

# Prepend mraa-utils to make sure bindir ends up in there
PACKAGES =+ "${PN}-utils"

FILES_${PN}-doc += "${datadir}/mraa/examples/"

FILES_${PN}-utils = "${bindir}/"

# override this in local.conf to get needed bindings.
# BINDINGS_pn-mraa="python"
# will result in only the python bindings being built/packaged.
BINDINGS ??= "python nodejs"

PACKAGECONFIG ??= "${@bb.utils.contains('PACKAGES', 'node-${PN}', 'nodejs', '', d)} \
 ${@bb.utils.contains('PACKAGES', '${PYTHON_PN}-${PN}', 'python', '', d)}"

PACKAGECONFIG[python] = "-DBUILDSWIGPYTHON=ON, -DBUILDSWIGPYTHON=OFF, swig-native ${PYTHON_PN},"
PACKAGECONFIG[nodejs] = "-DBUILDSWIGNODE=ON, -DBUILDSWIGNODE=OFF, swig-native nodejs-native,"
PACKAGECONFIG[ft4222] = "-DUSBPLAT=ON -DFTDI4222=ON, -DUSBPLAT=OFF -DFTDI4222=OFF,, libft4222"

FILES_${PYTHON_PN}-${PN} = "${PYTHON_SITEPACKAGES_DIR}/"
RDEPENDS_${PYTHON_PN}-${PN} += "${PYTHON_PN}"

FILES_node-${PN} = "${prefix}/lib/node_modules/"
RDEPENDS_node-${PN} += "nodejs"

### Include desired language bindings ###
PACKAGES =+ "${@bb.utils.contains('BINDINGS', 'nodejs', 'node-${PN}', '', d)}"
PACKAGES =+ "${@bb.utils.contains('BINDINGS', 'python', '${PYTHON_PN}-${PN}', '', d)}"
