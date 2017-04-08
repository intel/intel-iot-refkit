SUMMARY = "IoT Reference OS Kit initramfs image"
DESCRIPTION = "Finds the boot partition via PARTUUID, optionally supports IMA, LUKS, dm-verity."

PACKAGE_INSTALL = "busybox base-passwd ${ROOTFS_BOOTSTRAP_INSTALL} ${FEATURE_INSTALL}"

require refkit-boot-settings.inc

# Do not build by default, some relevant settings (like encryption keys)
# might be missing. If it is needed, it will get pulled in indirectly.
EXCLUDE_FROM_WORLD = "1"

# e2fs: loads fs modules and adds ext2/ext3/ext4=<device>:<path> boot parameter
#       for mounting additional partitions

# used to detect boot devices automatically
PACKAGE_INSTALL += "initramfs-module-udev"

# Create variants of this recipe for each image mode. Each variant
# depends on a specific variant of initramfs-framework-refkit-dm-verity.
IMAGE_MODE_VALID = "${REFKIT_IMAGE_MODE_VALID}"
inherit image-mode-variants

# Do not pollute the initrd image with rootfs features
IMAGE_FEATURES = ""

# Instead we have additional image feature(s).
IMAGE_FEATURES[validitems] += " \
    ima \
    luks \
    dm-verity \
    debug \
"
IMAGE_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ima', 'ima', '', d)} \
"
FEATURE_PACKAGES_ima = "initramfs-framework-ima"
IMAGE_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'luks', 'luks', '', d)} \
"
FEATURE_PACKAGES_luks = "initramfs-framework-refkit-luks"
IMAGE_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'dm-verity', 'dm-verity', '', d)} \
"
FEATURE_PACKAGES_dm-verity = "initramfs-framework-refkit-dm-verity${IMAGE_MODE_SUFFIX}"

# debug: adds debug boot parameters like 'shell' and 'debug', see
#        meta/recipes-core/initrdscripts/initramfs-framework/debug for details
IMAGE_FEATURES += " \
    ${@ 'debug' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' } \
"
FEATURE_PACKAGES_debug = "initramfs-module-debug"

# OSTree support: we add the module if the distro supports OSTree.
# It does not do anything in images not using OSTree.
IMAGE_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ostree', 'ostree', '', d)} \
"
FEATURE_PACKAGES_ostree = "initramfs-framework-ostree"

IMAGE_LINGUAS = ""

LICENSE = "MIT"

IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"
inherit core-image

BAD_RECOMMENDATIONS += "busybox-syslog"

# Ensure that we install the additional files needed for IMA/EVM
# by inheriting ima-evm-rootfs, even though no files need to be
# signed in the initramfs itself.
#
# For the rootfs we use the IMA example policy which allows both
# signed and hashed files (installed as part of
# initramfs-framework-ima.bb) and sign the rootfs accordingly (in
# refkit-image.bb).
IMA_EVM_ROOTFS_SIGNED = "-maxdepth 0 -false"
IMA_EVM_ROOTFS_HASHED = "-maxdepth 0 -false"
IMA_EVM_ROOTFS_CLASS = "${@bb.utils.contains('IMAGE_FEATURES', 'ima', 'ima-evm-rootfs', '',d)}"
inherit ${IMA_EVM_ROOTFS_CLASS}

create_merged_usr_links() {
    mkdir -p ${IMAGE_ROOTFS}${libdir} ${IMAGE_ROOTFS}${bindir} ${IMAGE_ROOTFS}${sbindir}
    lnr ${IMAGE_ROOTFS}${libdir} ${IMAGE_ROOTFS}/${baselib}
    lnr ${IMAGE_ROOTFS}${bindir} ${IMAGE_ROOTFS}/bin
    lnr ${IMAGE_ROOTFS}${sbindir} ${IMAGE_ROOTFS}/sbin
}
ROOTFS_PREPROCESS_COMMAND += "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', 'create_merged_usr_links;', '', d)}"

