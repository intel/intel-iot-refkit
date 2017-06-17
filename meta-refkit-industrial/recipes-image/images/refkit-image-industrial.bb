SUMMARY = "IoT Reference OS Kit image for Industrial profile."
DESCRIPTION = "IoT Reference OS Kit image for Industrial profile."

REFKIT_IMAGE_INDUSTRIAL_EXTRA_FEATURES ?= "${REFKIT_IMAGE_FEATURES_COMMON}"
REFKIT_IMAGE_INDUSTRIAL_EXTRA_INSTALL ?= "${REFKIT_IMAGE_INSTALL_COMMON}"
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_IMAGE_INDUSTRIAL_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_IMAGE_INDUSTRIAL_EXTRA_INSTALL}"

REFKIT_IMAGE_INDUSTRIAL_EXTRA_INSTALL_append = " packagegroup-industrial-robotics"

# Example for customization in local.conf when building
# refkit-image-industrial.bb:
# IMAGE_BASENAME_pn-refkit-image-industrial = "my-refkit-image-reference"
# REFKIT_IMAGE_INDUSTRIAL_EXTRA_INSTALL_append = "my-own-package"
# REFKIT_IMAGE_INDUSTRIAL_EXTRA_FEATURES_append = "dev-pkgs"

# inherit refkit-image

# Currently ROS (genmsg in particular) does not build if usrmerge is
# enabled. As a horrendous kludge, we only inherit refkit-image if
# usrmerge is not among DISTRO_FEATURES, thus letting this image de-
# generate to a NOP if usrmerge is enabled.
#
# Note that we need to also replicate the LICENSE-setting here in
# case refkit-image does not get inherited, otherwise the bitbake
# recipe-parser bails out.

LICENSE = "MIT"
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', \
              '', 'refkit-image', d)}
