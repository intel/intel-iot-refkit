# This recipe creates a module for the initramfs-framework in OE-core
# which opens the partition identified via the root
# kernel parameter as a LUKS container and changes bootparam_root so
# that the following init code uses the decrypted volume.
#
# Currently a proof-of-concept with a fixed password, do not use in
# production!

SUMMARY = "LUKS module for the modular initramfs system"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
RDEPENDS_${PN} += "initramfs-framework-base"

require refkit-boot-settings.inc

inherit check-available
CHECK_AVAILABLE[keyutils] = "${HAVE_CRYPTSETUP}"

refkit_luks[shellcheck] = "sh"
refkit_luks () {

    luks_enabled() {
        [ "$bootparam_root" ]
    }

    luks_run () {
        C=0
        delay=${bootparam_rootdelay:-1}
        timeout=${bootparam_roottimeout:-5}

        if [ "$(echo "$bootparam_root" | cut -c1-5)" = "UUID=" ]; then
            root_uuid=$(echo "$bootparam_root" | cut -c6-)
            bootparam_root=/dev/disk/by-uuid/$root_uuid
        fi

        if [ "$(echo "$bootparam_root" | cut -c1-9)" = "PARTUUID=" ]; then
            root_uuid=$(echo "$bootparam_root" | cut -c10-)
            bootparam_root=/dev/disk/by-partuuid/$root_uuid
        fi

        while true; do
            seconds=$( expr "$C" '*' "$delay" )
            # shellcheck disable=SC2035
            if [ "$seconds" -gt "$timeout" ]; then
                fatal "LUKS root partition $bootparam_root not found."
            fi

            # The same refkit-initramfs is used for live boot from USB stick
            # and for locked-down booting from internal disk, therefore it
            # has to support booting with and without encryption.
            #
            # TODO: However, when booting from an internal disk, it must
            # enforce encryption, otherwise an attacker could downgrade
            # the installation from encrypted LUKS to something unencrypted
            # under his control. The data would be gone, but integrity
            # protection would have failed.
            #
            # TODO: use two different initramfs variants and set up devices
            # so that they only boot less secure installer images until
            # installed, then reject them in the future.
            if [ -e "$bootparam_root" ]; then
                cryptsetup isLuks "$bootparam_root" 2>/dev/null
                case $? in
                  0) # LUKS volumne found
                    keyfile=$(mktemp)
                    keyfile_offset=
                    tcsd_pid=
                    IFDOWN=true
                    luks_cleanup () {
                        dd if=/dev/zero of="$keyfile" count="$(stat -c '%s' "$keyfile")" bs=1 >/dev/null
                        rm "$keyfile"
                        if [ "$tcsd_pid" ]; then
                            kill "$tcsd_pid"
                        fi
                        $IFDOWN lo
                    }
                    if ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'true', 'false', d) } &&
                       [ -e /dev/tpm0 ] &&
                       ((tpm2_nvread -v | grep -q "version 2.1" && TPM2TOOLS_TCTI_NAME=device tpm2_dump_capabilities -c commands >/dev/null 2>/dev/null) ||
                        TPM2TOOLS_TCTI_NAME=device tpm2_getcap -c commands >/dev/null 2>/dev/null); then
                       TPM2TOOLS_TCTI_NAME=device
                       TPM2TOOLS_DEVICE_FILE=/dev/tpm0
                       export TPM2TOOLS_TCTI_NAME TPM2TOOLS_DEVICE_FILE

                       size="$( expr "${REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN}" + "${REFKIT_DISK_ENCRYPTION_KEY_SIZE}" )"
                       if tpm2_nvread -v | grep -q "version 2.1"; then
                           # Reading the data is weird. We have to parse stdout to extract the actual bytes:
                           # $ tpm2_nvread -x 0x1500001 -a 0x40000001 -o 0 -s 8
                           #
                           # The size of data:8
                           #  68  65  6c  6c  6f  0a  ff  ff
                           if ! out="$(tpm2_nvread -x '${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}' -a 0x40000001 -s $size -o 0)"; then
                                luks_cleanup
                                fatal "Error reading NVRAM area with index ${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}"
                           fi
                           for c in $(echo "$out" | grep -v 'The size of data'); do printf "\\x$c"; done >"$keyfile"
                        else
                           # tpm2.0-tools 3.x can write into a file.
                           if ! tpm2_nvread -x '${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}' -a 0x40000001 -s $size -o 0 -f "$keyfile"; then
                                luks_cleanup
                                fatal "Error reading NVRAM area with index ${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}"
                           fi
                        fi
                        keyfile_offset="${REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN}"
                        if [ "$(head -c "$keyfile_offset" "$keyfile")" != "${REFKIT_DISK_ENCRYPTION_NVRAM_ID}" ]; then
                            luks_cleanup
                            fatal "Unexpected content in NVRAM area"
                        fi
                        # Lock access until next reboot.
                        if ! tpm2_nvreadlock -x '${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}' -a 0x40000001 -P ""; then
                            luks_cleanup
                            fatal "Error locking NVRAM area with index ${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX_TPM2}"
                        fi
                    elif ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm', 'true', 'false', d) } &&
                       ls /dev/tpm* >/dev/null 2>&1; then
                        # Bring up IPv4 (needed by tcsd and tpm-tools) and tcsd itself.
                        ifup lo
                        IFDOWN=ifdown
                        tcsd -f &
                        tcsd_pid=$!
                        while true; do
                           if ! kill -0 "$tcsd_pid"; then
                               luks_cleanup
                               fatal "tcsd terminated unexpectedly"
                           fi
                           # Once tcsd has sockets open, we can talk to it.
                           # shellcheck disable=SC2010
                           if ls -l "/proc/$tcsd_pid/fd" | grep -q -w "socket"; then
                               break
                           fi
                           sleep 1
                        done

                        if ! tpm_nvread -i "${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}" -f "$keyfile" -z; then
                            luks_cleanup
                            fatal "Error reading NVRAM area with index ${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}"
                        fi
                        keyfile_offset="${REFKIT_DISK_ENCRYPTION_NVRAM_ID_LEN}"
                        if [ "$(head -c "$keyfile_offset" "$keyfile")" != "${REFKIT_DISK_ENCRYPTION_NVRAM_ID}" ]; then
                            luks_cleanup
                            fatal "Unexpected content in NVRAM area"
                        fi
                        # Lock access until next reboot.
                        if ! tpm_nvread -i "${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}" -s 0 -z; then
                            luks_cleanup
                            fatal "Error locking NVRAM area with index ${REFKIT_DISK_ENCRYPTION_NVRAM_INDEX}"
                        fi
                    fi
                    if [ ! -s "$keyfile" ]; then
                        if [ "${REFKIT_DISK_ENCRYPTION_PASSWORD}" ]; then
                            printf "%s" "${REFKIT_DISK_ENCRYPTION_PASSWORD}" >"$keyfile"
                            keyfile_offset=0
                        else
                            # Empty keyfile is almost certainly not right. Warn about it, but then proceed just in case.
                            msg "Empty LUKS key! Retrieving it from TPM was disabled or impossible and no fixed password was set either. 'cryptsetup open' is probably going to fail now, but will try anyway."
                        fi
                    fi
                    if cryptsetup open --type luks "$bootparam_root" "${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}" --key-file "$keyfile" --keyfile-offset "$keyfile_offset"; then
                        bootparam_root="/dev/mapper/${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}"
                        luks_cleanup
                        return
                    fi
                    luks_cleanup
                    # We allow booting to continue instead of aborting. Perhaps the error was temporary
                    # and the next loop iteration will succeed. If not, we'll return eventually and
                    # then the normal "no rootfs" handling takes over.
                    ;;
                  1) # not a LUKS volume, which might be a problem (attacker replaced encrypted rootfs with modified unencrypted one)
                    if [ "$bootparam_use_encryption" ] ; then
                        fatal "$bootparam_root is not a LUKS volume."
                    fi
                    return
                    ;;
                  *) # something else
                    debug "Error accessing $bootparam_root via cryptsetup"
                    ;;
                esac
            fi

            debug "Sleeping for $delay second(s) to wait root to settle..."
            sleep "$delay"
            C=$( expr $C + 1 )
        done
    }

}

python do_install () {
    import os

    os.makedirs(os.path.join(d.getVar('D'), 'init.d'))
    with open(os.path.join(d.getVar('D'), 'init.d', '80-luks'), 'w') as f:
        f.write(d.getVar('refkit_luks'))
}

# netbase is needed because it enables IPv6, and tpm-tools happens
# to communicate with trousers via IPv6. Probably could be reconfigured
# to use only IPv4.
#
# libgcc is needed by tpm-tools and has to be specified explicitly because of
# https://bugzilla.yoctoproject.org/show_bug.cgi?id=10954
FILES_${PN} = "/init.d"
RDEPENDS_${PN} = " \
    cryptsetup \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm', 'trousers tpm-tools libgcc strace netbase init-ifupdown', '', d) } \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'tpm2-tools', '', d) } \
"
