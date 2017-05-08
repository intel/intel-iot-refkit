# This recipe creates a module for the initramfs-framework in OE-core
# which opens the partition identified via the "root"
# kernel parameter using the dm-verity hashes stored in
# the partition identified via the "dmverity" kernel
# parameter and changes bootparam_root so
# that the following init code uses the read-only,
# integrity protected mapped partition.

SUMMARY = "dm-verity module for the modular initramfs system"
LICENSE = "MIT"
DEPENDS = "openssl-native"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

require refkit-boot-settings.inc

refkit_dmverity[shellcheck] = "sh"
refkit_dmverity () {

    dmverity_enabled() {
        [ "$bootparam_dmverity" ]
    }

    dmverity_run () {
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

        if [ "$(echo "$bootparam_dmverity" | cut -c1-5)" = "UUID=" ]; then
            root_uuid=$(echo "$bootparam_dmverity" | cut -c6-)
            bootparam_dmverity=/dev/disk/by-uuid/$root_uuid
        fi

        if [ "$(echo "$bootparam_dmverity" | cut -c1-9)" = "PARTUUID=" ]; then
            root_uuid=$(echo "$bootparam_dmverity" | cut -c10-)
            bootparam_dmverity=/dev/disk/by-partuuid/$root_uuid
        fi

        while true; do
            seconds=$( expr "$C" '*' "$delay" )
            # shellcheck disable=SC2035
            if [ "$seconds" -gt "$timeout" ]; then
                fatal "root partition $bootparam_root and/or dm-verity hash partition $bootparam_dmverity not found."
            fi

            if [ -e "$bootparam_root" ] && [ -e "$bootparam_dmverity" ]; then
                signature=$(grep -n -m 1 -e "^signature=" "$bootparam_dmverity")
                if [ ! "$signature" ]; then
                    fatal "no signature found in dm-verity hash partition $bootparam_dmverity"
                fi
                header_lines="$( expr "$(echo "$signature" | sed -e 's/:.*//')" - 1 )"
                header=$(mktemp)
                if ! head "-$header_lines" "$bootparam_dmverity" >"$header"; then
                    fatal "failed to read header from $bootparam_dmverity"
                fi
                sigfile=$(mktemp)
                echo "$signature" | sed -e 's/^[0-9]*:signature=//' | openssl base64 -d >"$sigfile"
                result=$(openssl dgst -sha256 -verify /etc/dm-verity-pubkey.pem -signature "$sigfile" "$header")
                if [ "$?" != 0 ] || [ "$result" != "Verified OK" ]; then
                    fatal "dm-verity header in $bootparam_dmverity did not pass OpenSSL signature verification"
                fi

                eval "$(grep -e ^roothash= -e ^headersize= "$header")"
                if ! veritysetup create "${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}" "$bootparam_root" "$bootparam_dmverity" "$roothash" --hash-offset "$headersize"; then
                    fatal "veritysetup of rootfs $bootparam_root using dm-verity hash partition $bootparam_dmverity failed"
                fi
                bootparam_root="/dev/mapper/${REFKIT_DEVICE_MAPPER_ROOTFS_NAME}"
                return
            fi

            debug "Sleeping for $delay second(s) to wait root to settle..."
            sleep "$delay"
            C=$( expr $C + 1 )
        done
    }

}

python do_install () {
    import os
    import subprocess

    os.makedirs(os.path.join(d.getVar('D'), 'init.d'))
    with open(os.path.join(d.getVar('D'), 'init.d', '80-dmverity'), 'w') as f:
        f.write(d.getVar('refkit_dmverity'))

    privkey = d.getVar('REFKIT_DMVERITY_PRIVATE_KEY')
    password = d.getVar('REFKIT_DMVERITY_PASSWORD')
    pubkey = os.path.join(d.getVar('D'), 'etc', 'dm-verity-pubkey.pem')
    os.makedirs(os.path.dirname(pubkey))
    subprocess.check_output(['openssl', 'rsa', '-in', privkey, '-passin', password, '-pubout', '-out', pubkey],
                            stderr=subprocess.STDOUT)
}

inherit refkit-hash-dm-verity-key
do_install[vardeps] += "REFKIT_DMVERITY_PRIVATE_KEY_HASH"

FILES_${PN} = "/init.d /etc"
RDEPENDS_${PN} += " \
    initramfs-framework-base \
    cryptsetup \
    openssl \
"
