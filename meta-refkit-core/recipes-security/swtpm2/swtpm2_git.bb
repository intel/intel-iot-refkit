SUMMARY = "SWTPM2.0 - Software TPM2.0 Emulator"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=fe8092c832b71ef20dfe4c6d3decb3a8"
SECTION = "apps"

DEPENDS = "libtasn1 fuse expect socat glib-2.0 libtpms2"

# configure checks for the tools already during compilation and
# then swtpm_setup needs them at runtime
DEPENDS += "tpm-tools-native expect-native socat-native"
RDEPENDS_${PN} += "tpm-tools"

SRCREV = "adf9b3fe5d4df6708e9f801b8c9dcfdf7274d457"
SRC_URI = " \
	git://github.com/stefanberger/swtpm.git;nobranch=1 \
	file://fix_lib_search_path.patch \
        file://ioctl_h.patch \
	"
PV = "0.1.0-dev2"

S = "${WORKDIR}/git"

inherit autotools-brokensep pkgconfig
PARALLEL_MAKE = ""

TSS_USER="tss"
TSS_GROUP="tss"

PACKAGECONFIG ?= "openssl"
PACKAGECONFIG += "${@bb.utils.contains('DISTRO_FEATURES', 'selinux', 'selinux', '', d)}"
PACKAGECONFIG[openssl] = "--with-openssl, --without-openssl, openssl"
PACKAGECONFIG[gnutls] = "--with-gnutls, --without-gnutls, gnutls"
PACKAGECONFIG[selinux] = "--with-selinux, --without-selinux, libselinux"
PACKAGECONFIG[cuse] = "--with-cuse, --without-cuse"
PACKAGECONFIG[debug] = "--enable-debug, --disable-debug"

EXTRA_OECONF += "--with-tss-user=${TSS_USER} --with-tss-group=${TSS_GROUP}"

export SEARCH_DIR = "${STAGING_LIBDIR_NATIVE}"

# dup bootstrap 
do_configure_prepend () {
	libtoolize --force --copy
	autoheader
	aclocal
	automake --add-missing -c
	autoconf
}

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM_${PN} = "--system ${TSS_USER}"
USERADD_PARAM_${PN} = "--system -g ${TSS_GROUP} --home-dir  \
    --no-create-home  --shell /bin/false ${BPN}"

RDEPENDS_${PN} = "libtpm expect socat bash"

BBCLASSEXTEND = "native nativesdk"
