SUMMARY = "IoT Reference OS Kit image for interactive use, without profile-specific components."
DESCRIPTION = "IoT Reference OS Kit image for interactive use, without profile-specific component. This is the recommended image when testing whether IoT Reference OS Kit works on a device, because it builds faster than the profile images and contains some useful system debugging tools for interactive use and, last but not least, an SSH server."

# When not using swupd, it is possible to set per-image
# variables for a specific image recipe using the the _pn-<image name>
# notation. However, that stops working once the swupd feature gets
# enabled (because that internally relies on virtual images under
# different names), so the recommended approach is to have per-recipe
# variables (like REFKIT_IMAGE_COMMON_EXTRA_FEATURES) and customize
# those outside the recipe.
#
# For example, to enable swupd for the refkit-image-common, use this
# in local.conf:
# REFKIT_IMAGE_COMMON_EXTRA_FEATURES_append = " swupd"
#
# The default values are set in refkit-image.bbclass.
REFKIT_IMAGE_COMMON_EXTRA_FEATURES ?= "${REFKIT_IMAGE_FEATURES_COMMON}"
REFKIT_IMAGE_COMMON_EXTRA_INSTALL ?= "${REFKIT_IMAGE_INSTALL_COMMON}"
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_IMAGE_COMMON_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_IMAGE_COMMON_EXTRA_INSTALL}"

# Feature "common-test" is included if "development" version of the
# image is compiled.

# If the default "refkit-image-common" name is
# undesirable, write a custom image recipe similar to this one here (although
# refkit-image-minimal.bb might be a better starting point), or customize the
# image file names when continuing to use refkit-image-common.bb.
#
# Example for customization in local.conf when building refkit-image-common.bb:
# IMAGE_BASENAME_pn-refkit-image-common = "my-refkit-image-reference"
# REFKIT_IMAGE_COMMON_EXTRA_INSTALL_append = "my-own-package"
# REFKIT_IMAGE_COMMON_EXTRA_FEATURES_append = "dev-pkgs"

inherit refkit-image
