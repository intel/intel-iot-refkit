# If IMA is used, then the signing key must be configured explicitly
# in local.conf. In contrast to refkit-development.inc, no fallback
# is provided.

# Disable consoles and make journald quiet (=disable system logging).
REFKIT_IMAGE_EXTRA_FEATURES_append = " muted"

# Everything is (hopefully) ready, avoid initial sanity check.
REFKIT_IMAGE_BUILD_MODE_SELECTED = "1"
