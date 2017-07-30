SUMMARY = "refkit-image-computervision + wayland"

require recipes-image/images/refkit-image-computervision.bb

REQUIRED_DISTRO_FEATURES = "wayland"
inherit distro_features_check
