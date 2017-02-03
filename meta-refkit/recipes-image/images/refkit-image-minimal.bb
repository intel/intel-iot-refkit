SUMMARY = "IoT Reference OS Kit base image."
DESCRIPTION = "IoT Reference OS Kit image for local builds with swupd disabled and no optional components whatsoever. The expected usage is to copy this recipe into a custom layer under a different name and then modifying it there to define the image for an IoT Reference OS Kit based product."

# When not using swupd, it is possible to set per-image
# variables for a specific image recipe using the the _pn-<image name>
# notation. However, that stops working once the swupd feature gets
# enabled (because that internally relies on virtual images under
# different names), so the recommended approach is to have per-recipe
# variables (like REFKIT_IMAGE_MINIMAL_EXTRA_FEATURES) and customize
# those outside the recipe.
#
# For example, to enable swupd for the refkit-image-minimal, use this
# in local.conf:
# REFKIT_IMAGE_MINIMAL_EXTRA_FEATURES_append = " swupd"
REFKIT_IMAGE_MINIMAL_EXTRA_FEATURES ?= ""
REFKIT_IMAGE_MINIMAL_EXTRA_INSTALL ?= ""
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_IMAGE_MINIMAL_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_IMAGE_MINIMAL_EXTRA_INSTALL}"

inherit refkit-image
