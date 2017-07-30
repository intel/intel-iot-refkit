SUMMARY = "refkit-image-computervision + x11"

require recipes-image/images/refkit-image-computervision.bb

REQUIRED_DISTRO_FEATURES = "x11"
inherit distro_features_check
