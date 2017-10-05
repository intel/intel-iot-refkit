FILESEXTRAPATHS_prepend_df-refkit-groupcheck := "${THISDIR}/files:"

# Replace polkit backend engine with groupcheck.
# This is done by splitting out the client library
# and causing it to pull in groupcheck.
PACKAGES_prepend_df-refkit-groupcheck = "${PN}-lib "
FILES_${PN}-lib = " \
    ${libdir}/libpolkit-gobject*.so.* \
"
RDEPENDS_${PN}-lib = "groupcheck"

# In addition, we disable building the server and backend,
# because that pulls in the heavy mozjs + dependencies.
SRC_URI_append_df-refkit-groupcheck = " file://0001-disable-service-and-backend.patch"
DEPENDS_remove_df-refkit-groupcheck = "mozjs"
EXTRA_OECONF_append_df-refkit-groupcheck = " --disable-test"
SYSTEMD_SERVICE_${PN}_df-refkit-groupcheck = ""
do_install_append_df-refkit-groupcheck () {
    rm -rf ${D}${systemd_system_unitdir}
    rm -rf ${D}${libdir}/systemd
}
