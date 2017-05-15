SUMMARY = "IoT Reference OS Kit image for Computer Vision profile."
DESCRIPTION = "IoT Reference OS Kit image for Computer Vision profile."

REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES ?= "${REFKIT_IMAGE_FEATURES_COMMON}"
REFKIT_IMAGE_COMPUTERVISION_EXTRA_INSTALL ?= "${REFKIT_IMAGE_INSTALL_COMMON}"
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_IMAGE_COMPUTERVISION_EXTRA_INSTALL}"

REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES += "computervision"

# Feature "computervision-test" is included if "development" version of the
# image is compiled.
REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES += "${@ '' if (d.getVar('IMAGE_MODE') or 'production') == 'production' else 'computervision-test'}"

# Example for customization in local.conf when building
# refkit-image-computervision.bb:
# IMAGE_BASENAME_pn-refkit-image-computervision = "my-refkit-image-reference"
# REFKIT_IMAGE_COMPUTERVISION_EXTRA_INSTALL_append = "my-own-package"
# REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES_append = "dev-pkgs"

inherit refkit-image
