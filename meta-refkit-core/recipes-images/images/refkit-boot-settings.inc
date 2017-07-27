# refkit-initramfs and refkit-installer-image cooperate to implement
# whole-disk encryption and dm-verity. Some settings are shared
# and identical in the initramfs and the image it is used in.
#
# We provide two different kinds of refkit-initramfs: one with
# IMAGE_MODE=development (refkit-initramfs-development) and
# one for production (refkit-initramfs). The images then pick
# a suitable one depending on their own IMAGE_MODE.

# Determines what name is used under /dev/mapper/ for the rootfs.
REFKIT_DEVICE_MAPPER_ROOTFS_NAME ??= "rootfs"

# Insecure, well-known password as fallback when there is no TPM.
# Gets compiled into initramfs-framework-refkit-luks.bb and thus
# refkit-initramfs.
#
# Leaving the password empty disables the feature.
#
# To use it when enabled, call image-installer in the
# refkit-installer-image with
# "FIXED_PASSWORD=<password chosen via REFKIT_DISK_ENCRYPTION_PASSWORD>".
REFKIT_DISK_ENCRYPTION_PASSWORD ??= "${@ 'refkit' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' }"

# Use the pre-generated OpenSSL keys for dm-verity signing with
# well-known password "refkit" passed directly via the command line.
# Other openssl -passin variants (for example, file:<path to password file>)
# also work.
REFKIT_DMVERITY_PRIVATE_KEY ??= "${@ '${META_REFKIT_CORE_BASE}/files/dm-verity/private.pem' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' }"
REFKIT_DMVERITY_PASSWORD ??= "${@ 'pass:refkit' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' }"

# Pre-generated test/development keys for UEFI combo application signing
SECURE_BOOT_SIGNING_KEY ??= "${@ '${META_REFKIT_CORE_BASE}/files/secureboot/refkit-db.key' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' }"
SECURE_BOOT_SIGNING_CERT ??= "${@ '${META_REFKIT_CORE_BASE}/files/secureboot/refkit-db.crt' if (d.getVar('IMAGE_MODE') or 'production') != 'production' else '' }"

# Index of the TPM NVRAM area used for random the per-machine disk encryption key.
# The area contains a short ID + version, followed by the key.
REFKIT_DISK_ENCRYPTION_NVRAM_INDEX ??= "1"
REFKIT_DISK_ENCRYPTION_NVRAM_ID ??= "REFKIT_0"
REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN = "${@ len('${REFKIT_DISK_ENCRYPTION_NVRAM_ID}') }"

# Default size of the random disk encryption key (only used during installation,
# initramfs determines the size based on what is in the NVRAM area).
REFKIT_DISK_ENCRYPTION_KEY_SIZE ??= "32"
