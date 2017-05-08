
#enable merged /usr
REFKIT_DEFAULT_DISTRO_FEATURES += "usrmerge"

export base_bindir = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${exec_prefix}/bin', '${base_prefix}/bin', d)}"
export base_sbindir = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${exec_prefix}/sbin', '${base_prefix}/sbin', d)}"
export base_libdir = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${exec_prefix}/${baselib}', '${base_prefix}/${baselib}', d)}"
export nonarch_base_libdir = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${exec_prefix}/lib', '${base_prefix}/lib', d)}"

#nativesdk
base_bindir_nativesdk = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${bindir_nativesdk}', '/bin', d)}"
base_sbindir_nativesdk = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${sbindir_nativesdk}', '/sbin', d)}"
base_libdir_nativesdk = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${libdir_nativesdk}', '/lib', d)}"

DISTRO_FEATURES_remove = " gobject-introspection-data"


