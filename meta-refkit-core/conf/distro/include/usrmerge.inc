#enable merged /usr
REFKIT_DEFAULT_DISTRO_FEATURES += "usrmerge"

# Change the configuration to point all base folder to /usr
export base_bindir = "${base_prefix}/usr/bin"
export base_sbindir = "${base_prefix}/usr/sbin"
export base_libdir = "${base_prefix}/usr/${baselib}"
export nonarch_base_libdir = "${base_prefix}/usr/lib"

#nativesdk
base_bindir_class-nativesdk = "${SDKPATHNATIVE}${base_bindir_nativesdk}"
base_sbindir_class-nativesdk = "${SDKPATHNATIVE}${base_sbindir_nativesdk}"
base_libdir_class-nativesdk = "${SDKPATHNATIVE}${base_libdir_nativesdk}"

target_base_libdir_class-cross = "${target_base_prefix}/usr/lib"

# Disable split-usr support in systemd and point the rootprefix to /usr
EXTRA_OECONF_append_pn-systemd = " --disable-split-usr"
rootprefix_pn-systemd = "${exec_prefix}"

# Most of shell scripts refer to '#!/bin/{sh,bash}' inside the script. But, when
# root folders(/bin, /lib, /sbin) merged with their /usr counterparts this path
# would be /usr/bin/{sh, bash}.  The builder complains that 'no package provides
# '/bin/{sh/bash}''. So to satisfy builder adding '/bin/{sh,bash}' to bash,
# busybox package providers list.  This is a temporary hack till we get a
# solution from oe-core
# Links to Upstream patches:
#  http://lists.openembedded.org/pipermail/openembedded-core/2017-February/133148.html
#  http://lists.openembedded.org/pipermail/openembedded-core/2017-February/133149.html
