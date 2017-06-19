# util-linux-native tooling enables to use either lzo or lz4 compression.
# We prefer lz4 so switch to use it.
#
# Upstream-Status: Inappropriate [Downstream configuration] 

DEPENDS_remove_class-native_df-refkit-config = "lzo-native"
DEPENDS_remove_class-nativesdk_df-refkit-config = "lzo-native"
DEPENDS_append_class-native_df-refkit-config = " lz4-native"
DEPENDS_append_class-nativesdk_df-refkit-config = " lz4-native"

# nologin can come from two separate sources, shadow and util-linux.
# Normally these do not conflict, the one from shadow goes into /sbin,
# the one from util-linux goes into /usr/sbin. With usrmerge enabled,
# however, /sbin is symlinked to /usr/sbin and these start conflicting.
# If that happens, we make util-linux get out of the way by removing
# its nologin.
#
# Ideally we probably should make sure first that shadow is enabled to
# ensure we don't end up without any /{usr/,}sbin/nologin.

do_install_append_df-refkit-config () {
    if [ -n "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', 'y', '', d)}" ];
    then
        rm -f ${D}${sbindir}/nologin
    fi
}
