DESCRIPTION = "test content with user IDs"
LICENSE = "MIT"

inherit useradd allarch

do_install () {
    install -d ${D}${datadir}
    echo "hello" >${D}${datadir}/refkit-test-content-hello
    echo "world" >${D}${datadir}/refkit-test-content-world
    chmod 0644 ${D}${datadir}/*
    chown groupcheck:groupcheck ${D}${datadir}/refkit-test-content-hello
    chown polkitd:polkitd ${D}${datadir}/refkit-test-content-world
}

# We pick users here for which Refkit already has static IDs.
USERADD_PACKAGES = "${PN}-hello ${PN}-world"
USERADD_PARAM_${PN}-hello = "--system --no-create-home --user-group groupcheck"
USERADD_PARAM_${PN}-world = "--system --no-create-home --user-group polkitd"

PACKAGES = "${PN}-hello ${PN}-world"
FILES_${PN}-hello = "${datadir}/refkit-test-content-hello"
FILES_${PN}-world = "${datadir}/refkit-test-content-world"
