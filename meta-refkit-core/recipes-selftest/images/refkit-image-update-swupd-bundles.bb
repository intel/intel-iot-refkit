SUMMARY = "test image: refkit-image-update-swupd + bundles"

require refkit-image-update-swupd.bb

SWUPD_BUNDLES = "feature_one feature_two"
BUNDLE_CONTENTS[feature_one] = "refkit-test-feature-hello"
BUNDLE_CONTENTS[feature_two] = "refkit-test-feature-world"

SWUPD_IMAGES = "dev"
SWUPD_IMAGES[dev] = "feature_one feature_two"
