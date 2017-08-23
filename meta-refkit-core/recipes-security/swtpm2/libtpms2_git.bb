SUMMARY = "LIBPM - Software TPM Library"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=97e5eea8d700d76b3ddfd35c4c96485f"

SRCREV = "362fb5f5ef980133e00d6433ac880178ddf2c304"
SRC_URI = "git://github.com/stefanberger/libtpms.git;nobranch=1 \
"
PV = "v0.6.0-dev1"

S = "${WORKDIR}/git"
inherit autotools-brokensep pkgconfig

PACKAGECONFIG ?= "openssl tpm2"
PACKAGECONFIG[openssl] = "--with-openssl, --without-openssl, openssl"
PACKAGECONFIG[tpm2] = "--with-tpm2, --without-tpm2"
PACKAGECONFIG[debug] = "--enable-debug, --disable-debug"

PV = "1.0+git${SRCPV}"

BBCLASSEXTEND = "native nativesdk"
