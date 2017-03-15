SUMMARY = "upm"
DESCRIPTION = "test application for upm lib"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
DEPENDS = "upm"
SRC_URI = "file://upm_test.c \
"

inherit pkgconfig

S = "${WORKDIR}"

do_compile() {
    ${CC} upm_test.c $(pkg-config --libs upmc-utilities) ${LDFLAGS} -o upm_test $(pkg-config --cflags upmc-utilities)
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 upm_test ${D}${bindir}
}
