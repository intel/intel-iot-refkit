SUMMARY = "IoT Reference OS Kit image with embedded installer."
DESCRIPTION = "IoT Reference OS Kit image with embedded image-installer command for copying IoT Reference OS Kit onto internal storage of a device."

# The supported format for refkit images is wic because that is already getting built;
# installing files from it is a bit harder than using the tar format, but doable.
# Below, we use the kpartx command to get access to the rootfs files.
INSTALLER_SOURCE_IMAGES ?= " \
    refkit-image-common:wic \
    refkit-image-computervision:wic \
    refkit-image-gateway:wic \
"

# Allow wic to resize the image as needed by overriding the default fixes size.
REFKIT_IMAGE_SIZE ?= ""

require refkit-boot-settings.inc

# The refkit specific part is derived from the Ostro OS XT installer.
REFKIT_INSTALLER_UEFI_COMBO[shellcheck] = "sh"
REFKIT_INSTALLER_UEFI_COMBO () {
    populate () {
        output=$1
        gdisk_pnum=$2
        uuid=$3
        rootfs=$4
        output_mounted=
        output_mountpoint=
        output_luks=
        LUKS_NAME=installerrootfs
        LUKS_PASSWORD="${REFKIT_DISK_ENCRYPTION_PASSWORD}"
        # Use something which is guaranteed to not be persistent.
        keydir=$(TMPDIR=/dev/shm mktemp -dt keydir.XXXXXX)
        keyfile="$keydir/keyfile"
        keyfile_offset=

        cleanup_populate () {
            [ "$keydir" ] && (dd if=/dev/zero of="$keyfile" count=1 bs="${REFKIT_DISK_ENCRYPTION_KEY_SIZE}"; rm -rf "$keydir" )
            [ "$output_mounted" ] && execute umount "$output_mountpoint"
            [ "$output_mountpoint" ] && rmdir "$output_mountpoint"
            [ "$output_luks" ] && execute cryptsetup close "$output_luks"
            remove_cleanup cleanup_populate
        }
        add_cleanup cleanup_populate

        if ! output_mountpoint=$(mktemp -dt output-partition.XXXXXX); then
            fatal "could not create mount point"
        fi

        # Might be with or without p in the middle (sda1 vs mmcblk0p1).
        partition=
        for i in $output*$gdisk_pnum; do
            if [ -e "$i" ]; then
                if [ "$partition" ]; then
                    fatal "partition #$gdisk_pnum in $output not unique?!"
                fi
                partition=$i
            else
                fatal "$output*$gdisk_pnum not found in $output"
            fi
        done
        if [ ! "$partition" ]; then
            fatal "could not identify parition #$gdisk_pnum in $output"
        fi

        if [ "$uuid" ]; then
            if ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', 'true', 'false', d) }; then
                # This uses the well-known (all zero) owner and SRK secrets,
                # thus granting any process running on the device access to the
                # TPM.
                # TODO: lock down access to system processes?
                if ! execute tpm_takeownership -y -z; then
                    fatal "taking ownership of TPM failed - needs to be reset?"
                fi
                # We store a random key in the TPM NVRAM where it is accessible
                # to the initramfs. The initramfs will turn off read-access
                # after it has retrieved the key, so nothing else that gets started
                # later will have access to the key.
                if ! execute tpm_nvdefine -i "${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}" -s "$( expr "${REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN}" + "${REFKIT_DISK_ENCRYPTION_KEY_SIZE}" )" -p 'AUTHREAD|AUTHWRITE|READ_STCLEAR' -y -z; then
                    fatal "creating NVRAM area failed"
                fi
                if ! (printf "%s" "${REFKIT_DISK_ENCRYPTION_NVRAM_ID}" &&
                      dd if=/dev/urandom bs="${REFKIT_DISK_ENCRYPTION_KEY_SIZE}" count=1) >"$keyfile"; then
                    fatal "key creation failed"
                fi
                keyfile_offset="${REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN}"
                if ! execute tpm_nvwrite -i "${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}" -z -f "$keyfile"; then
                    fatal "storing key in NVRAM failed"
                fi
                # Lock access until reboot.
                if ! execute tpm_nvread -i "${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}" -z -s 0; then
                    fatal "locking key in NVRAM failed"
                fi
            fi

            # Unsafe fallback without TPM: well-known password.
            # TODO: detect when this ends up getting used in production.
            if [ ! -s "$keyfile" ]; then
                printf "%s" "$LUKS_PASSWORD" >"$keyfile"
                keyfile_offset=0
            fi
            if ${@ bb.utils.contains('DISTRO_FEATURES', 'luks', 'true', 'false', d) }; then
                if ! execute cryptsetup luksFormat "$partition" --batch-mode --key-file "$keyfile" --keyfile-offset "$keyfile_offset"; then
                    fatal "formatting $partition as LUKS contained failed"
                fi
                if ! execute cryptsetup open --type luks "$partition" "$LUKS_NAME" --key-file "$keyfile" --keyfile-offset "$keyfile_offset"; then
                    fatal "opening $partition as LUKS container failed"
                fi
                output_luks=$LUKS_NAME
                partition=/dev/mapper/$LUKS_NAME
            fi
            # Assume that there's only one ext4 partition and it contains root fs (/)
            if ! execute mkfs.ext4 -q -v -F -U "$uuid" "$partition"; then
                fatal "formatting target rootfs partition $gdisk_pnum failed"
            fi
            if ! execute mount -t ext4 "$partition" "$output_mountpoint"; then
                fatal "mounting target rootfs failed"
            else
                output_mounted=1
            fi
            if ! execute rsync -aAX "$rootfs/" "$output_mountpoint/"; then
                fatal "copying rootfs failed"
            fi
        else
            if ! execute mkfs.fat "$partition"; then
                fatal "formating vfat partition $gdisk_pnum failed"
            fi
            if ! execute mount -t vfat "$partition" "$output_mountpoint"; then
                fatal "mounting target vfat partition $gdisk_pnum failed"
            else
                output_mounted=1
            fi
            if ! execute cp -r "$rootfs/boot/EFI_internal_storage" "$output_mountpoint/EFI"; then
                fatal "copying EFI files failed"
            fi
        fi
        if ! sync; then
            fatal "syncing data failed"
        fi
        cleanup_populate
    }

    install_image () {
        input="${INSTALLER_IMAGE_DATADIR}/$CHOSEN_INPUT"
        output="/dev/$CHOSEN_OUTPUT"
        info "Installing from $input to $output."

        confirm_install || return 1

        input_mountpoint=
        input_mounted=

        cleanup_install_image () {
            [ "$input_mounted" ] && execute umount "$input_mountpoint"
            [ "$input_mountpoint" ] && rmdir "$input_mountpoint"
            [ "$input" ] && execute kpartx -d "$input"
            remove_cleanup cleanup_install_image
        }
        add_cleanup cleanup_install_image

        # Assume that there's only one ext4 partition at the end and it
        # contains the systems' rootfs.
        loopdev=$(execute kpartx -sav "$input" | tail -1 | sed -e 's/^\(add map \)*\([^ ]*\).*/\2/')
        if [ ! "$loopdev" ]; then
            fatal "kpartx failed for $input"
        fi
        if ! input_mountpoint=$(mktemp -dt input-rootfs.XXXXXX); then
            fatal "could not create mount point"
        fi
        if ! execute mount "/dev/mapper/$loopdev" "$input_mountpoint"; then
            fatal "count not mount rootfs from /dev/mapper/$loopdev"
        else
            input_mounted=1
        fi

        # Clear all partition data on disk
        if ! execute sgdisk -o "$output"; then
            fatal "sgdisk $output has failed - damaged disk?"
        fi

        # Read partition description from rootfs.
        if ! . "$input_mountpoint/boot/emmc-partitions-data"; then
            fatal "reading $input_mountpoint/boot/emmc-partitions-data failed"
        fi

        # Create partitions.
        pnum=0
        gdisk_pnum=1
        while [ "$pnum" -lt "$PART_COUNT" ]; do
            eval size="\$PART_${pnum}_SIZE"
            eval uuid="\$PART_${pnum}_UUID"
            eval type_id="\$PART_${pnum}_TYPE"
            eval lname="\$PART_${pnum}_NAME"
            eval fs="\$PART_${pnum}_FS"

            if [ "$gdisk_pnum" -eq "$PART_COUNT" ]; then
                # Make the last partition take the rest of the space
                if ! execute sgdisk -n "$gdisk_pnum:+0:-1s" -c "$gdisk_pnum:$lname" \
                       -t "$gdisk_pnum:$type_id" -u "${gdisk_pnum}:${uuid}" -- "$output"; then
                    fatal "creating rootfs partition failed"
                fi
            else
                if ! execute sgdisk -n "$gdisk_pnum:+0:+${size}M" -c "$gdisk_pnum:$lname" \
                       -t "$gdisk_pnum:$type_id" -u "${gdisk_pnum}:${uuid}" -- "$output"; then
                    fatal "creating vfat partition $gdisk_pnum failed"
                fi
            fi

            if [ "$gdisk_pnum" -eq 1 ]; then
                # Set bootable flag on the first partition
                if ! execute sgdisk -A "${gdisk_pnum}:set:2" -- "$output"; then
                    fatal "making first partition bootable failed"
                fi
            fi

            if [ "$lname" = "rootfs" ]; then
                populate "$output" "$gdisk_pnum" "$uuid" "$input_mountpoint"
            else
                populate "$output" "$gdisk_pnum" "" "$input_mountpoint"
            fi

            pnum=$(expr $pnum + 1)
            gdisk_pnum=$(expr $gdisk_pnum + 1)
        done
        cleanup_install_image
    }
}
INSTALLER_INSTALL ?= "${REFKIT_INSTALLER_UEFI_COMBO}"

INSTALLER_RDEPENDS_append = " \
    dosfstools \
    e2fsprogs-mke2fs \
    gptfdisk \
    kpartx \
    rsync \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'luks', 'cryptsetup', '', d) } \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', 'trousers tpm-tools', '', d) } \
"


inherit image-installer

# When dm-verity support is enabled in the distro, the installer image
# by default uses a read-only partition with dm-verity used for integrity
# protection. This has the useful effect that corrupted data on a USB
# stick gets detected instead of silently writing a broken image to
# internal storage.
REFKIT_INSTALLER_IMAGE_EXTRA_FEATURES ?= " \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'dm-verity', 'read-only-rootfs dm-verity', '', d) } \
    ${REFKIT_IMAGE_FEATURES_COMMON} \
"
REFKIT_INSTALLER_IMAGE_EXTRA_INSTALL ?= "${REFKIT_IMAGE_INSTALL_COMMON}"
REFKIT_IMAGE_EXTRA_FEATURES += "${REFKIT_INSTALLER_IMAGE_EXTRA_FEATURES}"
REFKIT_IMAGE_EXTRA_INSTALL += "${REFKIT_INSTALLER_IMAGE_EXTRA_INSTALL}"

inherit refkit-image
