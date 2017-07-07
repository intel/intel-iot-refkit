# This file is meant to be included in a distro configuration.
# It adds support for the "stateless" distro and image feature,
# without actually turning them on.
#
# Addditional .inc files define the actual changes that a
# distro might want to apply.

# The stateless.bbclass modifies how some recipes are built
# when "stateless" is in DISTRO_FEATURES, so it needs to
# be inherited globally. This can be removed once STATELESS_SRC
# is no longer needed.
INHERIT += "stateless"

# Required to find local patches.
FILESEXTRAPATHS_prepend = "${@ bb.utils.contains('DISTRO_FEATURES', 'stateless', '${META_REFKIT_CORE_BASE}/files/stateless/${PN}:', '', d) }"

# Some entries in /etc simply have to be there, so we whitelist them
# to avoid failing the QA check for stateless images.

# mtab is a symlink to /proc/mounts.
STATELESS_ETC_WHITELIST += "mtab"

# /etc/machine-id could be removed if (and only if) the rootfs gets mounted rw.
# Note that this also triggers the ConditionFirstBoot, something
# that is not normally done in OE-core. It causes systemd to
# auto-enable units according to their [Install] sections, and
# at least for wpa_supplicant that is broken (https://www.reddit.com/r/archlinux/comments/4mnkyu/timeout_during_boot/?st=j03jwv0d&sh=14c1a955
# http://lists.infradead.org/pipermail/hostap/2017-March/037330.html)
# Therefore we always keep it.
STATELESS_ETC_WHITELIST += "machine-id"

# /etc/fstab can be removed only under special circumstances:
# - no local file systems besides root
# - rootfs gets mounted rw immediately
# - no additional special mount options for root that need
#   to be applied via remount
#
# This is too complicated to check here, therefore /etc/fstab
# is left in place by default. A distro where fstab is known
# to be not needed can do:
# STATELESS_RM_ROOTFS += "fstab"
# STATELESS_ETC_WHITELIST_remove = "fstab"
STATELESS_ETC_WHITELIST += "fstab"

# If we want to be stateless, override the /etc/build default.
# It currently gets created after STATELESS_MV_ROOTFS, so
# we can't do it that way.
python () {
    buildinfo_file = d.getVar('IMAGE_BUILDINFO_FILE')
    if bb.utils.contains('IMAGE_FEATURES', 'stateless', True, False, d) and \
       buildinfo_file is not None and buildinfo_file == '/etc/build':
       d.setVar('IMAGE_BUILDINFO_FILE', '${libdir}/build')
}

# /etc/xdg/systemd/user symlinks to this, so keep the directory even when empty.
STATELESS_ETC_DIR_WHITELIST += "systemd/user"

# Likewise for /usr/lib/ssl/certs -> /etc/ssl/certs and ssl/private.
STATELESS_ETC_DIR_WHITELIST += "ssl/certs ssl/private"
