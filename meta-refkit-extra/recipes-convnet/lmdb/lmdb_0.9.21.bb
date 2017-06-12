SUMMARY = "Symas Lightning Memory-Mapped Database (LMDB)"
HOMEPAGE = "http://symas.com/mdb/"
LICENSE = "OLDAP-2.8"
LIC_FILES_CHKSUM = "file://LICENSE;md5=153d07ef052c4a37a8fac23bc6031972"

SRC_URI = " \
    https://github.com/LMDB/lmdb/archive/LMDB_${PV}.tar.gz \
    file://0001-Patch-the-main-Makefile.patch \
"
SRC_URI[md5sum] = "41a4f7b63212a00e53fabd8159008201"
SRC_URI[sha256sum] = "1187b635a4cc415bb6972bba346121f81edd996e99b8f0816151d4090f90b559"

inherit autotools-brokensep

S = "${WORKDIR}/lmdb-LMDB_${PV}/libraries/liblmdb"

do_compile() {
    oe_runmake "CC=${CC}"
}

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${libdir}
    install -d ${D}${includedir}
    install -d ${D}${mandir}
    sed -i 's:\$(prefix)/man:${mandir}:' Makefile
    oe_runmake DESTDIR=${D} prefix=${prefix} manprefix=${mandir} install
}
