# This class implements image creation for the refkit target.
# The image is GPT based.
# To boot, it uses a combo file, containing kernel, initramfs and
# command line, presented to the BIOS as UEFI application, by prepending
# it with the efi stub obtained from systemd-boot.
# The layout of the image is described in a separate, customizable json file.

# By default, the full image is meant to fit into 4*10^9 bytes, i.e.
# "4GB" regardless whether 1000 or 1024 is used as base. 64M are reserved
# for potential partitioning overhead.
WKS_FILE = "refkit-directdisk.wks.in"
REFKIT_VFAT_MB ??= "64"
REFKIT_IMAGE_SIZE ??= "--fixed-size 3622M"
REFKIT_EXTRA_PARTITION ??= ""
WIC_CREATE_EXTRA_ARGS += " -D"

# Needed to use native python libraries
inherit pythonnative

# Image files of machines using image-dsk.bbclass do not use the redundant ".rootfs"
# suffix. Probably should be moved to refkit.conf eventually.
IMAGE_NAME_SUFFIX = ""

do_uefiapp[depends] += " \
                         systemd-boot:do_deploy \
                         rmc-db:do_deploy \
                         virtual/kernel:do_deploy \
                         initramfs-framework:do_populate_sysroot \
                         intel-microcode:do_deploy \
                         ${INITRD_IMAGE}:do_image_complete \
                       "

# Always ensure that the INITRD_IMAGE gets added to the initramfs .cpio.
# This needs to be done even when the actual .dsk image format is inactive,
# because the .cpio file gets copied into the rootfs, and that rootfs
# must be consistent regardless of the image format. This became relevant
# when adding swupd bundle support, because there virtual images
# without active .dsk are used to generate the rootfs for other
# images with .dsk format.
INITRD_LIVE_append = "${@ ('${DEPLOY_DIR_IMAGE}/' + d.getVar('INITRD_IMAGE', expand=True) + '-${MACHINE}.cpio.gz') if d.getVar('INITRD_IMAGE', True) else ''}"

PACKAGES = " "
EXCLUDE_FROM_WORLD = "1"

REMOVABLE_MEDIA_ROOTFS_PARTUUID_VALUE ?= "deadbeef-dead-beef-dead-beefdeadbeef"

# Partition types used for building the image - DO NOT MODIFY
PARTITION_TYPE_EFI = "EF00"
PARTITION_TYPE_EFI_BACKUP = "2700"

DSK_IMAGE_LAYOUT ??= '{}'

inherit deploy

# The image does without traditional bootloader.
# In its place, instead, it uses a single UEFI executable binary, which is
# composed by:
#   - an UEFI stub
#     The linux kernel can generate a UEFI stub, however the one from systemd-boot can fetch
#     the command line from a separate section of the EFI application, avoiding the need to
#     rebuild the kernel.
#   - the kernel
#   - the initramfs
#   There is a catch: all of these binary components must have the same word size as the BIOS:
#   either 32 or 64 bit.
python do_uefiapp() {
    import random, string, json, uuid, shutil, glob, re
    import shutil
    from subprocess import check_call

    # This data is imported by OS installer and used for partitioning internal storage
    PART_DATA_TPL = """
export PART_%(pnum)d_NAME=%(name)s
export PART_%(pnum)d_SIZE=%(size_mb)d
export PART_%(pnum)d_UUID=%(uuid)s
export PART_%(pnum)d_TYPE=%(type)s
export PART_%(pnum)d_FS=%(filesystem)s
"""
    partition_data = ""

    layout = d.getVar('DSK_IMAGE_LAYOUT', True)
    bb.note("Parsing disk image JSON %s" % layout)
    partition_table = json.loads(layout)

    full_image_size_mb = partition_table["gpt_initial_offset_mb"] + \
                         partition_table["gpt_tail_padding_mb"] \
                         if partition_table else 0

    rootfs_type = ''
    pnum = 0
    for key in sorted(partition_table.keys()):
        if not isinstance(partition_table[key], dict):
            continue
        full_image_size_mb += partition_table[key]["size_mb"]
        # Generate randomized uuids only if required uuid == 0
        # Otherwise leave whatever was set in the configuration file.
        if str(partition_table[key]['uuid']) == '0':
            partition_table[key]['uuid'] = str(uuid.uuid4())
        # Store these for the creation of the UEFI binary
        if partition_table[key]['name'] == 'rootfs':
            rootfs_type = 'rootfstype=%s ' % partition_table[key]['filesystem']
            int_part_uuid = d.getVar('INT_STORAGE_ROOTFS_PARTUUID_VALUE', True)
        else:
            int_part_uuid = partition_table[key]["uuid"]
        partition_data += PART_DATA_TPL % {
            "pnum": pnum,
            "size_mb": partition_table[key]["size_mb"],
            "uuid": int_part_uuid,
            "type": partition_table[key]["type"],
            "name": partition_table[key]["name"],
            "filesystem": partition_table[key]["filesystem"],
        }
        pnum = pnum + 1

    if pnum > 0:
        partition_data += "export PART_COUNT=%d\n" % pnum

    if os.path.exists(d.expand('${B}/initrd')):
        os.remove(d.expand('${B}/initrd'))
    # initrd is a concatenation of compressed cpio archives
    # (initramfs, microcode, etc.)
    with open(d.expand('${B}/initrd'), 'wb') as dst:
        for cpio in d.getVar('INITRD_LIVE', True).split():
            with open(cpio, 'rb') as src:
                dst.write(src.read())
    with open(d.expand('${B}/machine.txt'), 'w') as f:
        f.write(d.expand('${MACHINE}'))
    if '64' in d.getVar('MACHINE', True):
        executable = 'bootx64.efi'
    else:
        executable = 'bootia32.efi'

    def generate_app(partuuid, cmdline, suffix):
        with open(d.expand('${B}/cmdline' + suffix + '.txt'), 'w') as f:
            f.write(d.expand('${APPEND} root=PARTUUID=%s %s%s' % \
                             (partuuid, rootfs_type, cmdline)))
        check_call(d.expand('objcopy ' +
                          '--add-section .osrel=${B}/machine.txt ' +
                              '--change-section-vma  .osrel=0x20000 ' +
                          '--add-section .cmdline=${B}/cmdline' + suffix + '.txt ' +
                              '--change-section-vma .cmdline=0x30000 ' +
                          '--add-section .linux=${DEPLOY_DIR_IMAGE}/bzImage ' +
                              '--change-section-vma .linux=0x40000 ' +
                          '--add-section .initrd=${B}/initrd ' +
                              '--change-section-vma .initrd=0x3000000 ' +
                          glob.glob(d.expand('${DEPLOY_DIR_IMAGE}/linux*.efi.stub'))[0] +
                          ' ${B}/' + executable + suffix
                          ).split())
        if not os.path.exists(d.expand('${DEPLOYDIR}/EFI' + suffix + '/BOOT')):
            os.makedirs(d.expand('${DEPLOYDIR}/EFI' + suffix + '/BOOT'))
        shutil.copyfile(d.expand('${B}/' + executable + suffix), d.expand('${DEPLOYDIR}/EFI' + suffix + '/BOOT/' + executable))

    generate_app(d.getVar('REMOVABLE_MEDIA_ROOTFS_PARTUUID_VALUE', True), "installer", "")
    generate_app(d.getVar('INT_STORAGE_ROOTFS_PARTUUID_VALUE', True), "", "_internal_storage")

    if partition_data:
        with open(d.expand('${B}/emmc-partitions-data'), 'w') as emmc_part_data:
            emmc_part_data.write(partition_data)
        shutil.copyfile(d.expand('${B}/emmc-partitions-data'), d.expand('${DEPLOYDIR}/emmc-partitions-data'))

    # The RMC database is deployed unconditionally but not read if the BIOS is in SecureBoot mode.
    # XXX: However, the check for SecureBoot is not present. The bug is tracked in
    # https://bugzilla.yoctoproject.org/show_bug.cgi?id=11030
    shutil.copyfile(d.expand('${DEPLOY_DIR_IMAGE}/rmc.db'), d.expand('${DEPLOYDIR}/rmc.db'))
}

DEPLOYDIR = "${WORKDIR}/uefiapp-${PN}"
SSTATETASKS += "do_uefiapp"
do_uefiapp[vardeps] += " APPEND"
do_uefiapp[sstate-inputdirs] = "${DEPLOYDIR}"
do_uefiapp[sstate-outputdirs] = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}-uefiapp"

python do_uefiapp_setscene () {
    sstate_setscene(d)
}

uefiapp_sign() {
    if [ -f ${REFKIT_DB_KEY} ] && [ -f ${REFKIT_DB_CERT} ]; then
        for i in `find ${DEPLOYDIR} -name '*.efi'`; do
            sbsign --key ${REFKIT_DB_KEY} --cert ${REFKIT_DB_CERT} $i
            sbverify --cert ${REFKIT_DB_CERT} $i.signed
            mv $i.signed $i
        done
    else
        bbfatal "REFKIT_DB_KEY and REFKIT_DB_CERT must be set to file names for the signing key when using the 'secureboot' image feature."
    fi
}

uefiapp_deploy() {
  #Let's make sure that only what is needed stays in the /boot dir
  rm -rf ${IMAGE_ROOTFS}/boot/*
  cp  --preserve=timestamps -r ${DEPLOYDIR}/* ${IMAGE_ROOTFS}/boot/
  chown -R root:root ${IMAGE_ROOTFS}/boot
}

do_uefiapp[dirs] = "${DEPLOYDIR} ${B}"

addtask do_uefiapp_setscene
addtask do_uefiapp

addtask do_uefiapp before do_rootfs

# Re-run do_rootfs (and signing) if the key content changes. The name is irrelevant.
# Also checks that the variables are set at parse time instead of failing during image building.
do_rootfs[vardeps] += '${@bb.utils.contains('IMAGE_FEATURES','secureboot','REFKIT_DB_CERT_HASH REFKIT_DB_KEY_HASH','',d)}'
python () {
    import os
    import hashlib

    for varname in ('REFKIT_DB_CERT', 'REFKIT_DB_KEY'):
        filename = d.getVar(varname)
        if not filename:
            continue
        if not os.path.isfile(filename):
            bb.fatal('%s=%s is not a file.' % (varname, filename))
        with open(filename, 'rb') as f:
            data = f.read()
        hash = hashlib.sha256(data).hexdigest()
        d.setVar('%s_HASH' % varname, hash)

        # Must reparse and thus rehash on file changes.
        bb.parse.mark_dependency(d, filename)
}
do_rootfs[depends] += '${@bb.utils.contains('IMAGE_FEATURES','secureboot','sbsigntool-native:do_populate_sysroot','',d)}'

ROOTFS_POSTPROCESS_COMMAND += " ${@bb.utils.contains('IMAGE_FEATURES','secureboot','uefiapp_sign;','',d)} "
ROOTFS_POSTPROCESS_COMMAND += " uefiapp_deploy; "
