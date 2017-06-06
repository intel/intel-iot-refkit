# With usrmerge enabled, we need to let FUSE know where to put its mount.
FUSE_MOUNT_PATH = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', \
                       '/usr/sbin', '/sbin', d)}"

do_configure_prepend() {
    export MOUNT_FUSE_PATH="${FUSE_MOUNT_PATH}"
}

# Upstream-Status: Submitted [openembedded-devel@lists.openembedded.org]
