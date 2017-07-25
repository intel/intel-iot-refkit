SUMMARY = "refkit-image-common + Wayland"

require ${META_REFKIT_CORE_BASE}/recipes-images/images/refkit-image-common.bb

REQUIRED_DISTRO_FEATURES = "wayland"
inherit distro_features_check
