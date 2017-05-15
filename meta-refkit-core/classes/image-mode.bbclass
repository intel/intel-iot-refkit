# Some distros may want to build images in different modes ("development",
# "production", etc.). The same image recipe might get built differently
# based on local configuration, or different image recipes might inherit
# from the same base and just differ in their mode. This class introduces
# "IMAGE_MODE" as the per-image variable which controls this mode.
#
# IMAGE_MODE is intentionally a separate variable. This way, IMAGE_FEATURES
# can be set dynamically depending on IMAGE_MODE.
#
# There are no pre-defined modes. Distros which want to use modes
# must set the IMAGE_MODE_VALID variable, either globally or per image.
# Distros which don't have modes can still use the class to trigger
# an error message when developers set the variable although it doesn't
# have an effect.

# The default is to have no fixed mode.
IMAGE_MODE ??= ""

# Set this in the distro or image to enable mode support. For example:
# IMAGE_MODE_VALID ??= "production development debugging"

# Optionally this class extends /etc/motd in each image depending on the
# IMAGE_MODE of the image. To use this, set IMAGE_MODE_MOTD[<image mode>]
# to a string for that mode or IMAGE_MODE_MOTD[none] for empty or
# unset IMAGE_MODE. IMAGE_MODE_MOTD is used as default when the varflag
# is not set.
#
# When the motd text is empty, /etc/motd is not touched at all.
#
# Example:
# IMAGE_MODE_MOTD_NOT_PRODUCTION () {
# *********************************************
# *** This is a ${IMAGE_MODE} image! ${@ ' ' * (19 - len(d.getVar('IMAGE_MODE')))} ***
# *** Do not use in production.             ***
# *********************************************
# }
# IMAGE_MODE_MOTD = "${IMAGE_MODE_MOTD_NOT_PRODUCTION}"
# IMAGE_MODE_MOTD[production] = ""

# Empty when IMAGE_MODE is unset, otherwise -<IMAGE_MODE>.
IMAGE_MODE_SUFFIX = "${@ '-' + d.getVar('IMAGE_MODE') if d.getVar('IMAGE_MODE') else '' }"

python () {
    # Sanity checks for IMAGE_MODE.
    image_mode = d.getVar('IMAGE_MODE')
    mode = set(image_mode.split())
    if len(mode) == 0:
        return
    if len(mode) > 1:
        bb.fatal('An image can only be built in exactly one mode: IMAGE_MODE=%s' % image_mode)
    mode = mode.pop()
    valid = d.getVar('IMAGE_MODE_VALID') or ''
    if mode not in valid.split():
        bb.fatal('Invalid image mode: IMAGE_MODE=%s (not in %s)' % (image_mode, valid))
}

python image_mode_motd () {
    image_mode = d.getVar('IMAGE_MODE')
    motd = d.getVarFlag('IMAGE_MODE_MOTD', image_mode or 'none')
    if motd is None:
        motd = d.getVar('IMAGE_MODE_MOTD')
    if motd:
        with open(d.expand('${IMAGE_ROOTFS}${sysconfdir}/motd'), 'a') as f:
            f.write(motd)
}
ROOTFS_POSTPROCESS_COMMAND += "image_mode_motd;"
