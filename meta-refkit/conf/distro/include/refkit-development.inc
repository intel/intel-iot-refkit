# Use the pre-generated OpenSSL keys for dm-verity signing with
# well-known password "refkit" passed directly via the command line.
# Other openssl -passin variants (for example, file:<path to password file>)
# also work.
REFKIT_DMVERITY_PRIVATE_KEY = "${META_REFKIT_BASE}/files/dm-verity/private.pem"
REFKIT_DMVERITY_PASSWORD = "pass:refkit"

# Pre-generated test/development keys for UEFI combo application signing
REFKIT_DB_KEY ?= "${META_REFKIT_BASE}/files/secureboot/refkit-db.key"
REFKIT_DB_CERT ?= "${META_REFKIT_BASE}/files/secureboot/refkit-db.crt"

# Build a fixed password into refkit-initramfs for testing purposes.
REFKIT_DISK_ENCRYPTION_PASSWORD = "refkit"

# Enable local root access. Always use _append, to
# avoid getting this change overwritten by a
# REFKIT_IMAGE_EXTRA_FEATURES = "foo" in local.conf.
REFKIT_IMAGE_EXTRA_FEATURES_append = " autologin"

# Mark images as "development" by extending /etc/motd.
REFKIT_EXTRA_MOTD () {
************************************
*** This is a development image! ***
*** Do not use in production.    ***
************************************
}

# Everything ready, avoid initial sanity check.
REFKIT_IMAGE_BUILD_MODE_SELECTED = "1"

REFKIT_IMAGE_COMPUTERVISION_EXTRA_FEATURES_append = " computervision-test"
REFKIT_IMAGE_FEATURES_COMMON_append = " common-test"
