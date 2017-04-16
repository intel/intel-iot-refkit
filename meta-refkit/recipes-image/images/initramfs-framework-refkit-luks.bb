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
                    luks_cleanup () {
                        dd if=/dev/zero of="$keyfile" count=1 bs="$(stat -c '%s' "$keyfile")"
                        rm "$keyfile"
                        if [ "$tcsd_pid" ]; then
                            kill "$tcsd_pid"
                        fi
                        ifdown lo
                    }
                    if ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', 'true', 'false', d) } &&
                       ls /dev/tpm* >/dev/null 2>&1; then
                        # Bring up IPv4 (needed by tcsd and tpm-tools) and tcsd itself.
                        ifup lo
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
                        od "$keyfile"
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
                    if [ ! -s "$keyfile" ] &&
                       [ "${REFKIT_DISK_ENCRYPTION_PASSWORD}" ]; then
                        printf "%s" "${REFKIT_DISK_ENCRYPTION_PASSWORD}" >"$keyfile"
                        keyfile_offset=0
                    fi
                    if cryptsetup open --type luks "$bootparam_root" "${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}" --key-file "$keyfile" --keyfile-offset "$keyfile_offset"; then
                        bootparam_root="/dev/mapper/${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}"
                        luks_cleanup
                        return
                    fi
                    luks_cleanup
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
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', 'trousers tpm-tools libgcc strace netbase init-ifupdown', '', d) } \
"
