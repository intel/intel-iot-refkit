# Recipe changes not yet upstream which are needed to build images
# with no GPLv3-licenses components. Upstream OE-core changes will
# have this configurable, here it only depends on the "refkit-config"
# distro feature.
DEPENDS_remove_df-refkit-config = "readline gdbm db"
DEPENDS_append_df-refkit-config = "ncurses"
PACKAGES_remove_df-refkit-config = "${PN}-readline ${PN}-gdbm ${PN}-db"
PROVIDES_remove_df-refkit-config = "${PN}-readline ${PN}-gdbm ${PN}-db"
RRECOMMENDS_${PN}-core_remove_df-refkit-config = "${PN}-readline"
RDEPENDS_${PN}-modules_remove_df-refkit-config = "${PN}-readline ${PN}-gdbm ${PN}-db"
