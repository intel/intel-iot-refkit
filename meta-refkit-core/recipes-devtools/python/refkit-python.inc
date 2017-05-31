# Recipe changes not yet upstream which are needed to build images
# with no GPLv3-licenses components. Upstream OE-core changes will
# have this configurable, here it only depends on the "refkit-config"
# distro feature.
DEPENDS_remove_refkit-config = "readline gdbm db"
PACKAGES_remove_refkit-config = "${PN}-readline"
PROVIDES_remove_refkit-config = "${PN}-readline"
RRECOMMENDS_${PN}-core_remove_refkit-config = "${PN}-readline"
RDEPENDS_${PN}-modules_remove_refkit-config = "${PN}-readline"
