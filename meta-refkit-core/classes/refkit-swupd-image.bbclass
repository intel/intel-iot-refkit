# Meant to be inherited by refkit-image.bbclass if, and only if,
# swupd is enabled as an image feature. Contains the swupd-specific
# image settings.

inherit swupd-image

# Activate support for updating EFI system partition when using
# both meta-swupd and the EFI kernel+initramfs combo.
IMAGE_INSTALL_append = "${@ ' efi-combo-trigger' if ${REFKIT_USE_DSK_IMAGES} else '' }"

# Workaround when both Smack and swupd are used:
# Setting a label explicitly on the directory prevents it
# from inheriting other undesired attributes like security.SMACK64TRANSMUTE
# from upper folders (see xattr-images.bbclass for details).
DEPENDS_append = " \
    ${@ bb.utils.contains('IMAGE_FEATURES', 'swupd', 'attr-native', '', d)} \
"
fix_var_lib_swupd () {
    if ${@bb.utils.contains('IMAGE_FEATURES', 'smack', 'true', 'false', d)}; then
        install -d ${IMAGE_ROOTFS}/var/lib/swupd
        setfattr -n security.SMACK64 -v "_" ${IMAGE_ROOTFS}/var/lib/swupd
    fi
}
ROOTFS_POSTPROCESS_COMMAND_append = " fix_var_lib_swupd;"

# Make progress messages from do_swupd_update visible as normal command
# line output, instead of just recording it to the logs. Useful
# because that task can run for a long time without any output.
SWUPD_LOG_FN ?= "bbplain"

# When using the "swupd" image feature, ensure that OS_VERSION is
# set as intended. The default for local build works, but yields very
# unpredictable version numbers (see refkit.conf for details).
#
# For example, build with:
#   BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE OS_VERSION" OS_VERSION=100 bitbake refkit-image-common
#   ...

# Customize priorities of alternative components. See refkit.conf.
#
# In general, Busybox or Toybox are preferred over alternatives.
# The expectation is that either Busybox or Toybox are used, but if
# both get installed, Toybox is used for those commands that it
# provides.
#
# It is still possible to build images with coreutils providing
# core system tools, one just has to remove Toybox/Busybox from
# the image.
export ALTERNATIVE_PRIORITY_BUSYBOX ?= "250"
export ALTERNATIVE_PRIORITY_TOYBOX ?= "280"
# systemd has priority 300, busybox must have less because
# we want halt/poweroff/reboot from systemd
export ALTERNATIVE_PRIORITY_BASH ?= "305"

# Both systemd and the efi_combo_updater have problems when
# "mount" is provided by busybox: systemd fails to remount
# the rootfs read/write and the updater segfaults because
# it does not parse the output correctly.
#
# For now avoid these problems by sticking to the traditional
# mount utilities from util-linux.
export ALTERNATIVE_PRIORITY_UTIL_LINUX ?= "305"
IMAGE_INSTALL += "util-linux-mount"
