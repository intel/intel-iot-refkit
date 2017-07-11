SUMMARY = "NSS module which can read user information from files in the same format as /etc/passwd and /etc/group stored in an alternate location"
LICENSE = "LGPL2.1"
LIC_FILES_CHKSUM = "file://COPYING;md5=fb1949d8d807e528c1673da700aff41f"

SRC_URI = "git://github.com/aperezdc/nss-altfiles.git;protocol=https"

# Modify these as desired
PV = "2.23.0+git${SRCPV}"
SRCREV = "42bec47544ad80d3e39342b11ea33da05ff9133d"

S = "${WORKDIR}/git"

SECURITY_CFLAGS = "${SECURITY_NO_PIE_CFLAGS}"

# nss-altfiles build rules are defined in a custom Makefile.
# Additional compile flags can be set with a configure shell script.
# Compilation then must use normal make instead of oe_runmake, because
# the later causes (among others) CFLAGS and CPPFLAGS to be
# overridden, which would disable important parts of the build
# rules.
do_configure () {
    ${S}/configure --datadir=${datadir}/defaults/etc --libdir=${libdir} --with-types=rpc,proto,hosts,network,service,pwd,grp,spwd,sgrp 'CFLAGS=${CFLAGS}' 'CXXFLAGS=${CXXFLAGS}'
    # Reconfiguring with different options does not cause a rebuild. Must clean
    # explicitly to achieve that.
    make MAKEFLAGS= clean
}

do_compile () {
	make MAKEFLAGS=
}

do_install () {
	make MAKEFLAGS= install 'DESTDIR=${D}'
}
