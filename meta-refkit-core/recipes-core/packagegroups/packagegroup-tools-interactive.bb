SUMMARY = "Tools expected in an interactive shell"
DESCRIPTION = "Tools listed here are meant to be useful when logged into a device \
and working in the shell interactively or with some custom scripts. In production \
images without shell access they are optional. Tools with a specific purpose like \
development, profiling or program debugging are listed in separate package groups. \
"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    ${@ 'atop' if oe.types.boolean(d.getVar('HAVE_ATOP') or '0') else '' } \
    bzip2 \
    connman-client \
    curl \
    gawk \
    gzip \
    ${@ 'htop' if oe.types.boolean(d.getVar('HAVE_HTOP') or '0') else '' } \
    ${@ 'iftop' if oe.types.boolean(d.getVar('HAVE_IFTOP') or '0') else '' } \
    iputils-arping \
    iputils-clockdiff \
    iputils-ping \
    iputils-ping6 \
    iputils-tracepath \
    iputils-tracepath6 \
    iputils-traceroute6 \
    ${@ 'lowpan-tools' if oe.types.boolean(d.getVar('HAVE_LOWPAN_TOOLS') or '0') else '' } \
    pciutils \
    procps \
    rsync \
    usbutils \
    ${@ 'vim' if oe.types.boolean(d.getVar('HAVE_VIM') or '0') else '' } \
    wget \
"
