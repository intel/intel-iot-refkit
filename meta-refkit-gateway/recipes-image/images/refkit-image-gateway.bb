SUMMARY = "IoT Reference OS Kit image for Gateway profile."
DESCRIPTION = "IoT Reference OS Kit image for Gateway profile."

REFKIT_IMAGE_GATEWAY_EXTRA_FEATURES ?= "${REFKIT_IMAGE_FEATURES_COMMON}"
REFKIT_IMAGE_GATEWAY_EXTRA_INSTALL ?= "${REFKIT_IMAGE_INSTALL_COMMON}"
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_IMAGE_GATEWAY_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_IMAGE_GATEWAY_EXTRA_INSTALL}"

REFKIT_IMAGE_GATEWAY_EXTRA_FEATURES += " \
    bluetooth-audio \
    iotivity \
    nodejs-runtime \
    sensors \
"

# Example for customization in local.conf when building
# refkit-image-gateway.bb:
# IMAGE_BASENAME_pn-refkit-image-gateway = "my-refkit-image-gateway"
# REFKIT_IMAGE_GATEWAY_EXTRA_INSTALL_append = " my-own-package"
# REFKIT_IMAGE_GATEWAY_EXTRA_FEATURES_append = " dev-pkgs"

inherit refkit-image
