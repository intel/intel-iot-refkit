# refkit-initramfs and refkit-installer-image cooperate to implement
# whole-disk encryption.

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
REFKIT_DISK_ENCRYPTION_PASSWORD ??= ""

# Index of the TPM NVRAM area used for random the per-machine disk encryption key.
# The area contains a short ID + version, followed by the key.
REFKIT_DISK_ENCRYPTION_NVRAM_INDEX ??= "1"
REFKIT_DISK_ENCRYPTION_NVRAM_ID ??= "REFKIT_0"
REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN = "${@ len('${REFKIT_DISK_ENCRYPTION_NVRAM_ID}') }"

# Default size of the random disk encryption key (only used during installation,
# initramfs determines the size based on what is in the NVRAM area).
REFKIT_DISK_ENCRYPTION_KEY_SIZE ??= "32"
