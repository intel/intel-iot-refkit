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
# We need no boot loaders and only a few of the default native tools.
WKS_FILE_DEPENDS = "e2fsprogs-native"
REFKIT_VFAT_MB ??= "64"
REFKIT_IMAGE_SIZE ??= "--fixed-size 3622M"
REFKIT_EXTRA_PARTITION ??= ""
WIC_CREATE_EXTRA_ARGS += " -D"

# Image files of machines using image-dsk.bbclass do not use the redundant ".rootfs"
# suffix. Probably should be moved to refkit.conf eventually.
IMAGE_NAME_SUFFIX = ""

# turned into root=PARTUUID=... by uefi-comboapp.bbclass
DISK_SIGNATURE_UUID = "${REMOVABLE_MEDIA_ROOTFS_PARTUUID_VALUE}"

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
inherit uefi-comboapp

# Create a second UEFI app with a different partuuid. It is going to be used
# when installed to internal media. The goal is to avoid booting from the installed
# UEFI app with a rootfs from the install media.
create_uefiapps_append () {
    uuid = d.getVar('INT_STORAGE_ROOTFS_PARTUUID_VALUE')
    if uuid:
        create_uefiapp(d, uuid=uuid, app_suffix='_internal_storage')
}

# Extend what's getting into /boot of the rootfs and from there into the
# EFI system partition (see refkit-directdisk.wks.in).
do_uefiapp_deploy_append () {
    uuid="${@ d.getVar('INT_STORAGE_ROOTFS_PARTUUID_VALUE') or ''}"
    if [ "$uuid" ]; then
        # uefi-comboapp.bbclass created a boot*_internal_storage.efi for us, but then
        # placed it into /boot/EFI. We want it in /boot/EFI_internal_storage with
        # the name expected by the UEFI firmware.
        mkdir -p ${IMAGE_ROOTFS}/boot/EFI_internal_storage/BOOT
        executable=`cd  ${IMAGE_ROOTFS}/boot/EFI/BOOT && ls -1 boot*_internal_storage.efi`
        mv ${IMAGE_ROOTFS}/boot/EFI/BOOT/$executable ${IMAGE_ROOTFS}/boot/EFI_internal_storage/BOOT/`echo $executable | sed -e 's/_internal_storage//'`
    fi

    # The RMC database is deployed unconditionally but not read if the BIOS is in SecureBoot mode.
    # XXX: However, the check for SecureBoot is not present. The bug is tracked in
    # https://bugzilla.yoctoproject.org/show_bug.cgi?id=11030
    #
    # Populating /boot with additional files is problematic for system update, because we only
    # have support in place for updating the combo app, but not for additional files. So this
    # rmc.db isn't going to get updated on devices. The proposal to embed rmc.db in the
    # combo app is also tracked in YOCTO #11030.
    cp ${DEPLOY_DIR_IMAGE}/rmc.db ${IMAGE_ROOTFS}/boot/
}

do_uefiapp_deploy[depends] += "rmc-db:do_deploy"
