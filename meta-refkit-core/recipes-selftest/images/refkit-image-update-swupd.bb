SUMMARY = "test image for RefkitSwupdUpdateTest: refkit-image-minimal + swupd"

# Must be set before parsing refkit-image.bbclass because it pulls in
# swupd-image.bbclass during parsing.
IMAGE_FEATURES_append = " swupd"
require ${META_REFKIT_CORE_BASE}/recipes-images/images/refkit-image-minimal.bb

# We need network connectivity (basically, DHCP).
REFKIT_IMAGE_EXTRA_FEATURES += "connectivity"

# Speed up testing by disabling the os-core zero pack.
# It is only needed for "swupd verify --install".
SWUPD_GENERATE_OS_CORE_ZERO_PACK = "false"

# BUILD_ID is fixed in the CI system and variable in local builds (=
# ${DATETIME}). To ensure consistent test results, we keep it fixed here.
BUILD_ID = "swupd-test-build"
