SUMMARY = "test image for RefkitOSTreeUpdateTest: refkit-image-common + OSTree"

require ${META_REFKIT_CORE_BASE}/recipes-images/images/refkit-image-common.bb
IMAGE_FEATURES_append = " ostree"

REQUIRED_DISTRO_FEATURES += "ostree"
inherit distro_features_check
