SUMMARY = "refkit-image-common + X11"

require ${META_REFKIT_CORE_BASE}/recipes-images/images/refkit-image-common.bb

REQUIRED_DISTRO_FEATURES = "x11"
inherit distro_features_check
