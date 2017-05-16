# Base class for IoT Reference OS Kit images.

REFKIT_IMAGE_EXTRA_INSTALL ?= ""
IMAGE_INSTALL = " \
		kernel-modules \
		packagegroup-core-boot \
		${MACHINE_EXTRA_RDEPENDS} \
		${MACHINE_EXTRA_RRECOMMENDS} \
		${ROOTFS_BOOTSTRAP_INSTALL} \
		${CORE_IMAGE_EXTRA_INSTALL} \
		${REFKIT_IMAGE_EXTRA_INSTALL} \
		"

# In IoT Reference OS Kit, /bin/sh is always dash, even if bash is installed for
# interactive use.
#IMAGE_INSTALL += "dash"

# Certain keywords, like "iotivity" are used in different contexts:
# - as image feature name
# - as bundle name (when using meta-swupd)
# - optional: as additional image suffix
#
# While this keeps the names short, it can also be a bit confusing and
# makes some of the definitions below look redundant. They are needed,
# though, because the naming convention could also be different.


# Image features sometimes affect image building (for example,
# ima enables image signing) and/or adds certain packages
# via FEATURE_PACKAGES.
#
# This is the list of image features which merely add packages.
#
# When using swupd bundles, each name here can be used to define a bundle,
# for example like this:
# SWUPD_BUNDLES = "tools-debug"
# BUNDLE_CONTENTS[tools-debug] = "${FEATURE_PACKAGES_tools-debug}"
REFKIT_IMAGE_PKG_FEATURES = " \
    common-test \
    connectivity \
    iotivity \
    nodejs-runtime \
    nodejs-runtime-tools \
    python-runtime \
    sensors \
    tools-debug \
    tools-develop \
    alsa \
    bluetooth-audio \
"

REFKIT_IMAGE_PKG_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'java', 'java-jdk', '', d)} \
    "

# Here is the complete list of image features, also including
# those that modify the image configuration.
#
# swupd = install swupd client and enabled generation of swupd bundles
IMAGE_FEATURES[validitems] += " \
    autologin \
    muted \
    ima \
    secureboot \
    smack \
    swupd \
    dm-verity \
    ${REFKIT_IMAGE_PKG_FEATURES} \
"

# An image derived from refkit-image.bbclass without additional configuration
# is very minimal. When building with swupd enabled, the content of the
# base image determines the "core-os" swupd bundle which contains the components
# which always must be present on a device.
#
# All additional components on top of the minimal ones defined by refkit-image.bbclass
# must be added explicitly by setting REFKIT_IMAGE_EXTRA_FEATURES or
# REFKIT_IMAGE_EXTRA_INSTALL (making them part of the core-os bundle when building
# with swupd and thus part of each image, or directly adding them to the image when
# building without swupd), or by defining additional bundles via
# SWUPD_BUNDLES.
IMAGE_FEATURES += " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ima', 'ima', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'smack', 'smack', '', d)} \
    ${REFKIT_IMAGE_EXTRA_FEATURES} \
"
REFKIT_IMAGE_EXTRA_FEATURES ?= ""

# Inheriting swupd-image.bbclass only works when meta-swupd is in
# bblayers.conf, which may or may not be the case. If not available,
# any image recipe using swupd gets skipped. This has to be done in
# two different functions, raising bb.parse.SkipPackage already while
# parsing fails (bitbake datastore not ready yet).
python () {
    if 'swupd' in d.getVar('IMAGE_FEATURES').split() and not d.getVar('LAYERVERSION_meta-swupd'):
        raise bb.parse.SkipPackage('meta-swupd is not available, must be added to bblayers.conf')
}
def refkit_swupd_image_class(d):
    if 'swupd' in d.getVar('IMAGE_FEATURES').split() and d.getVar('LAYERVERSION_meta-swupd'):
        return 'refkit-swupd-image'
    else:
        return ''
# Here we optionally inherit refkit-swupd-image.bbclass, which configures and activates swupd.
inherit ${@refkit_swupd_image_class(d)}

# When using dm-verity, the rootfs has to be read-only.
# An extra partition gets created by wic which holds the
# hash data for the rootfs partition, including a signed
# root hash.
#
# A suitable initramfs (like refkit-initramfs with the dm-verity
# image feature enabled) then validates the signed root
# hash and activates the rootfs. refkit-initramfs checks the
# "dmverity" boot parameter for that. If not present or
# the refkit-initramfs was built without dm-verity support,
# booting proceeds without integrity protection.
WKS_FILE_DEPENDS_append = " \
    ${@ bb.utils.contains('IMAGE_FEATURES', 'dm-verity', 'cryptsetup-native openssl-native', '', d)} \
"
REFKIT_DM_VERITY_PARTUUID = "12345678-9abc-def0-0fed-cba987654322"
REFKIT_DM_VERITY_PARTITION () {
part --source dm-verity --uuid ${REFKIT_DM_VERITY_PARTUUID} --label rootfs
}
REFKIT_EXTRA_PARTITION .= "${@ bb.utils.contains('IMAGE_FEATURES', 'dm-verity', d.getVar('REFKIT_DM_VERITY_PARTITION'), '', d) }"
APPEND_append = "${@ bb.utils.contains('IMAGE_FEATURES', 'dm-verity', ' dmverity=PARTUUID=${REFKIT_DM_VERITY_PARTUUID}', '', d) }"
WICVARS_append = "${@ bb.utils.contains('IMAGE_FEATURES', 'dm-verity', ' \
    REFKIT_DMVERITY_PRIVATE_KEY \
    REFKIT_DMVERITY_PRIVATE_KEY_HASH \
    REFKIT_DMVERITY_PASSWORD \
    ', '', d) } \
"
inherit refkit-hash-dm-verity-key

# Common profile has "packagegroup-common-test" that has packages that are
# used only in "development" configuration.
FEATURE_PACKAGES_common-test = "packagegroup-common-test"

# Additional features and packages used by all profile images
# and the refkit-image-common.bb. Not essential for booting
# and thus not included in refkit-image-minimal.bb. Product
# images are expected to pick-and-chose exactly the content
# they neeed instead of using these variables.
REFKIT_IMAGE_FEATURES_COMMON ?= " \
    connectivity \
    ssh-server-openssh \
    alsa \
    sensors \
"
REFKIT_IMAGE_INSTALL_COMMON ?= ""

FEATURE_PACKAGES_connectivity = "packagegroup-core-connectivity"

# "evmctl ima_verify <file>" can be used to check that a signed file is
# really unmodified.
FEATURE_PACKAGES_ima = "packagegroup-ima-evm-utils"

FEATURE_PACKAGES_iotivity = "packagegroup-iotivity"

FEATURE_PACKAGES_sensors = "packagegroup-sensors \
    ${@ bb.utils.contains('IMAGE_FEATURES', 'python-runtime', 'python-mraa python-upm', '', d)} \
    ${@ bb.utils.contains('IMAGE_FEATURES', 'nodejs-runtime', 'node-mraa node-upm', '', d)} \
"

FEATURE_PACKAGES_nodejs-runtime = "packagegroup-nodejs-runtime"
FEATURE_PACKAGES_nodejs-runtime-tools = "packagegroup-nodejs-runtime-tools"
FEATURE_PACKAGES_python-runtime = "packagegroup-python-runtime"

FEATURE_PACKAGES_alsa = "alsa-utils alsa-state"

FEATURE_PACKAGES_bluetooth-audio = "packagegroup-bluetooth-audio"

# git is not essential for compiling software, but include it anyway
# because it is the most common source code management tool.
FEATURE_PACKAGES_tools-develop = "packagegroup-core-buildessential git"

# Add bash because it is more convenient to use than dash.
# This does not change /bin/sh due to re-organized update-alternative
# priorities.
FEATURE_PACKAGES_tools-interactive = "packagegroup-tools-interactive bash"

# OE-core treats "valgrind" as part of tools-profile aka
# packagegroup-core-tools-profile.bb. We do not enable that set of tools
# in IoT Reference OS Kit because not all of them work and/or make sense, but valgrind
# makes sense, in particular for debugging, so we add it there.
# All our platforms support it, so this can be unconditional.
FEATURE_PACKAGES_tools-debug_append = " valgrind"

# Computer vision profile has package groups. The packages in
# packagegroup-computervision are used in both "production" and
# "development" configurations, but packages in
# packagegroup-computervision-test are used only in "development"
# configuration.
FEATURE_PACKAGES_computervision = "packagegroup-computervision"
FEATURE_PACKAGES_computervision-test = "packagegroup-computervision-test"

IMAGE_LINGUAS = " "

LICENSE = "MIT"

# See local.conf.sample for explanations.
REFKIT_ROOT_AUTHORIZED_KEYS ?= ""
ROOTFS_POSTPROCESS_COMMAND += "refkit_root_authorized_keys; "
refkit_root_authorized_keys () {
    mkdir ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh
    echo "${REFKIT_ROOT_AUTHORIZED_KEYS}" >>${IMAGE_ROOTFS}${ROOT_HOME}/.ssh/authorized_keys
    chmod -R go-rwx ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh
}

# Do not create ISO images by default, only HDDIMG will be created (if it gets created at all).
NOISO = "1"

# Here we assume that the kernel has virtio support. We need to use a
# strong assignment here to change the ?= default from qemuboot.bbclass.
# The additional variable still allows changing the actual value.
REFKIT_QB_DRIVE_TYPE = "/dev/vd"
QB_DRIVE_TYPE = "${REFKIT_QB_DRIVE_TYPE}"

inherit image_types_extra

# Replace the default "live" (aka HDDIMG) images with whole-disk images
REFKIT_VM_IMAGE_TYPES ?= ""
IMAGE_FSTYPES_append = " ${REFKIT_VM_IMAGE_TYPES}"

# unconditionally set in x86-base.inc so we just remove it to avoid
# getting image-live.bbclass inherited.
IMAGE_FSTYPES_remove = "live"

# Activate "dsk" image type.
IMAGE_CLASSES += "${@ 'image-dsk' if oe.types.boolean(d.getVar('REFKIT_USE_DSK_IMAGES') or '0') else ''}"

# By default, the full image is meant to fit into 4*10^9 bytes, i.e.
# "4GB" regardless whether 1000 or 1024 is used as base. 64M are reserved
# for potential partitioning overhead.
WKS_FILE = "refkit-directdisk.wks.in"
REFKIT_VFAT_MB ??= "64"
REFKIT_IMAGE_SIZE ??= "--fixed-size 3622M"
REFKIT_EXTRA_PARTITION ??= ""
WIC_CREATE_EXTRA_ARGS += " -D"

# Inherit after setting variables that get evaluated when importing
# the classes. In particular IMAGE_FSTYPES is relevant because it causes
# other classes to be imported.

inherit core-image extrausers image-buildinfo image-mode

BUILD_ID ?= "${DATETIME}"
# Do not re-trigger builds just because ${DATETIME} changed.
BUILD_ID[vardepsexclude] += "DATETIME"
IMAGE_BUILDINFO_VARS_append = " BUILD_ID"

IMAGE_NAME = "${IMAGE_BASENAME}-${MACHINE}-${BUILD_ID}"

# Enable initramfs based on initramfs-framework (chosen in
# core-image-minimal-initramfs.bbappend). All machines must
# boot with a suitable initramfs, because IMA initialization is done
# in it.
REFKIT_INITRAMFS ?= "refkit-initramfs"
INITRD_IMAGE_intel-core2-32 = "${REFKIT_INITRAMFS}"
INITRD_IMAGE_intel-corei7-64 = "${REFKIT_INITRAMFS}"
INITRD_IMAGE_intel-quark = "${REFKIT_INITRAMFS}"

# The expected disk layout is not compatible with the HDD format:
# HDD places the rootfs as loop file in a VFAT partition (UEFI),
# while the rootfs is expected to be in its own partition.
NOHDD = "1"

# Image creation: add here the desired value for the PARTUUID of
# the rootfs. WARNING: any change to this value will trigger a
# rebuild (and re-sign, if enabled) of the combo EFI application.
REMOVABLE_MEDIA_ROOTFS_PARTUUID_VALUE = "12345678-9abc-def0-0fed-cba987654321"
# The second value is needed for the system installed onto
# the device's internal storage in order to mount correct rootfs
# when an installation media is still inserted into the device.
INT_STORAGE_ROOTFS_PARTUUID_VALUE = "12345678-9abc-def0-0fed-cba987654320"

# Enable/disable IMA also in per-image boot parameters.
APPEND_append = "${@bb.utils.contains('IMAGE_FEATURES', 'ima', ' rootflags=i_version', ' no-ima', d)}"

# Conditionally include the class only if distro features indicate that
# integrity support is enabled. We cannot include unconditionally
# because meta-integrity and thus ima-evm-rootfs.bbclass might not
# be available.
#
# In contrast to checking DISTRO_FEATURES, checking IMAGE_FEATURES has
# to be delayed until needed, because it might still get changed
# during parsing (.bbappends, anonymous functions, ...).
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'ima', 'ima-evm-rootfs', '', d)}
ima_evm_sign_rootfs_prepend () {
    ${@bb.utils.contains('IMAGE_FEATURES', 'ima', '', 'return', d)}
}

# The logic for the "smack" image feature is reversed: when enabled,
# the boot parameters are not modified, which leads to "Smack is
# enabled". Removing the feature disables security and thus also
# Smack. This is relies on only supporting one MAC mechanism. Should
# we ever support more than one, the handling needs to be revised.
#
# When Smack is disabled via the distro feature, the image feature is
# also off, but security=none gets added anyway despite being redundant.
# It is kept as an additional indicator that the system boots without a MAC
# mechanism.
#
# The Edison BSP does not support APPEND, some other solution is needed
# for that machine.
APPEND_append = "${@bb.utils.contains('IMAGE_FEATURES', 'smack', '', ' security=none', d)}"

# Use what RMC gives, not the defaults in meta-intel machine configs
APPEND_remove_intel-corei7-64 = "console=ttyS0,115200"

# In addition, when Smack is disabled in the image but enabled in the
# distro, we strip all Smack xattrs from the rootfs. Otherwise we still
# end up with Smack labels in the filesystem although we neither need
# nor want them, because the packages that were compiled for the distro
# have Smack enabled and will set the xattrs while getting installed.
refkit_image_strip_smack () {
    echo "Removing Smack xattrs:"
    set -e
    cd ${IMAGE_ROOTFS}
    find . -exec sh -c "getfattr -h -m ^security.SMACK.* '{}' | grep -q ^security" \; -print | while read path; do
        # Print removed Smack attributes to the log before removing them.
        getfattr -h -d -m ^security.SMACK.* "$path"
        getfattr -h -d -m ^security.SMACK.* "$path" | grep ^security | cut -d = -f1 | while read attr; do
           setfattr -h -x "$xattr" "$path"
        done
    done
}
REFKIT_IMAGE_STRIP_SMACK = "${@ 'refkit_image_strip_smack' if not bb.utils.contains('IMAGE_FEATURES', 'smack', True, False, d) and bb.utils.contains('DISTRO_FEATURES', 'smack', True, False, d) else '' }"
do_rootfs[postfuncs] += "${REFKIT_IMAGE_STRIP_SMACK}"
DEPENDS += "${@ 'attr-native' if '${REFKIT_IMAGE_STRIP_SMACK}' else '' }"

# Disable running fsck at boot. System clock is typically wrong at early boot
# stage due to lack of RTC backup battery. This causes unnecessary fixes being
# made due to filesystem metadata time stamps being in future.
APPEND_append = " fsck.mode=skip"

# Ensure that images preserve Smack labels and IMA/EVM.
inherit ${@bb.utils.contains_any('IMAGE_FEATURES', ['ima','smack'], 'xattr-images', '', d)}

# Create all users and groups normally created only at runtime already at build time.
inherit systemd-sysusers

# Provide an image feature that disables all consoles and makes
# journald mute.
python() {
    if bb.utils.contains('IMAGE_FEATURES', 'muted', True, False, d):
        import re

        # Mangle cmdline to drop all consoles and add quiet option
        cmdline = d.getVar('APPEND', True)
        new=re.sub('console=\w+(,\w*)*\s','', cmdline) + ' quiet'
        d.setVar('APPEND', new)
}

# In addition to cmdline mangling, make sure journal only gets
# emergency errors and any lower priority messages do not get
# logged. This is temporary approach and the cleanest way to disable
# logging (compared with removing the journald binary and related
# services here). Once the systemd recipe gives us better granulatiry
# for packaging, the preferred way to avoid logging is
# to not install systemd-journald at all.
refkit_image_muted () {
    sed -i -e 's/^#\(MaxLevelStore=\).*/\1emerg/'\
           -e 's/^\(ForwardToSyslog=yes\)/#\1/' \
           ${IMAGE_ROOTFS}${sysconfdir}/systemd/journald.conf

    # Remove systemd-getty-generator to avoid (serial-)getty services
    # being created for kernel detected consoles.
    rm ${IMAGE_ROOTFS}${systemd_unitdir}/system-generators/systemd-getty-generator

    # systemd installs getty@tty1.service by default so remove it too
    rm -r ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/getty.target.wants
}
ROOTFS_POSTPROCESS_COMMAND += "${@bb.utils.contains('IMAGE_FEATURES', 'muted', 'refkit_image_muted;', '', d)}"

# Disable images that are unbuildable, with an explanation why.
# Attempts to build disabled images will show that explanation.
python () {
    if bb.utils.contains('IMAGE_FEATURES', 'ima', True, False, d):
        # This is not a complete sanity check, because which settings
        # are needed depends a lot on how signing is configured. But
        # IMA_EVM_X509 is always expected to be a valid file, so we
        # can test at least that.
        x509 = d.getVar('IMA_EVM_X509', True)
        import os
        if not os.path.isfile(x509):
            error = '''
IMA_EVM_X509 is not set to the name of an existing file.
Check whether IMA signing is configured correctly.

%s''' % '\n'.join(['%s = "%s"' % (x, d.getVar(x, True)) for x in ['IMA_EVM_KEY_DIR', 'IMA_EVM_PRIVKEY', 'IMA_EVM_X509', 'IMA_EVM_ROOT_CA']])
            # It would be neat to show also the unexpanded variable values,
            # but SkipRecipe or the code dumping it automatically expand
            # variables, so we cannot do that at the moment.
            raise bb.parse.SkipRecipe(error)
}

# Enable local auto-login of the root user (local = serial port and
# virtual console by default, can be configured).
REFKIT_LOCAL_GETTY ?= " \
    ${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@.service \
    ${IMAGE_ROOTFS}${systemd_system_unitdir}/getty@.service \
"
local_autologin () {
    sed -i -e 's/^\(ExecStart *=.*getty \)/\1--autologin root /' ${REFKIT_LOCAL_GETTY}
}
ROOTFS_POSTPROCESS_COMMAND += "${@bb.utils.contains('IMAGE_FEATURES', 'autologin', 'local_autologin;', '', d)}"

# Use image-mode.bbclass to add a warning to /etc/motd.
IMAGE_MODE_MOTD_NOT_PRODUCTION () {
*********************************************
*** This is a ${IMAGE_MODE} image! ${@ ' ' * (19 - len(d.getVar('IMAGE_MODE')))} ***
*** Do not use in production.             ***
*********************************************
}
IMAGE_MODE_MOTD = "${IMAGE_MODE_MOTD_NOT_PRODUCTION}"
IMAGE_MODE_MOTD[production] = ""

# Ensure that the os-release file contains values matching the current image creation build.
# We do not want to rebuild the the os-release package for that, because that would
# also trigger image rebuilds when nothing else changed.
#
# FIXME: make this work with both ${IMAGE_ROOTFS}/etc/ and ${IMAGE_ROOTFS}/usr/lib
refkit_image_patch_os_release () {
    sed -i \
        -e 's/build-id-to-be-added-during-image-creation/${BUILD_ID}/' \
        ${IMAGE_ROOTFS}/etc/os-release
}
refkit_image_patch_os_release[vardepsexclude] = " \
    BUILD_ID \
"
ROOTFS_POSTPROCESS_COMMAND += "refkit_image_patch_os_release; "

# The systemd-firstboot service makes no sense in IoT Reference OS Kit. If it runs
# (apparently triggered by not having an /etc/machine-id), it asks
# interactively on the console for a default timezone and locale. We
# cannot rely on users answering these questions.
#
# Instead we pre-configure some defaults in the image and can remove
# the useless service.
refkit_image_disable_firstboot () {
    for i in /etc/systemd /lib/systemd /usr/lib/systemd /bin /usr/bin; do
        d="${IMAGE_ROOTFS}$i"
        if [ -d "$d" ] && [ ! -h "$d" ]; then
            for e in $(find "$d" -name systemd-firstboot.service -o -name systemd-firstboot.service.d -o -name systemd-firstboot); do
                echo "disable_firstboot: removing $e"
                rm -rf "$e"
            done
        fi
    done
}
ROOTFS_POSTPROCESS_COMMAND += "refkit_image_disable_firstboot; "

# Defining serial consoles via the "console" boot parameter only works
# for at most one console. Documentation/serial-console.txt explicitly
# says "Note that you can only define one console per device type
# (serial, video)".
#
# So for images where we need more than one console, we have to
# configure systemd explicitly. We cover all consoles, just to be
# on the safe side (can't know for sure which of these are also
# given via "console" boot parameter).
#
# For one console, we rely on the boot parameter.
#
# This mirrors what systemd-serialgetty.bb does in other distros.
# In IoT Reference OS Kit we are not using systemd-serialgetty.bb because it is
# less flexible (has to be the same for all images, while here it
# can be set differently for different images).
refkit_image_system_serialgetty() {
    if [ $(echo '${SERIAL_CONSOLES}' | wc -w) -gt 1 ]; then
        # Make it possible to override the baud rate by moving
        # 115200,38400,9600 into the BAUDRATE environment variable.
        # Default is set here, but also overridden for each console
        # actived below.
        #
        # ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,38400,9600 %I $TERM
        # ->
        # Environment="BAUDRATE=115200,38400,9600"
        # ExecStart=-/sbin/agetty --autologin root --keep-baud $BAUDRATE %I $TERM
        sed -i -e 's/\(ExecStart=.* \)\([0-9,]*00\)/Environment="BAUDRATE=\2"\n\1$BAUDRATE/' '${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@.service'
        tmp="${SERIAL_CONSOLES}"
	for entry in $tmp; do
            baudrate=`echo $entry | sed 's/\;.*//'`
            ttydev=`echo $entry | sed -e 's/^[0-9]*\;//' -e 's/\;.*//'`
            # enable the service
            install -d ${IMAGE_ROOTFS}${systemd_system_unitdir}/getty.target.wants
            lnr ${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@.service \
                ${IMAGE_ROOTFS}${systemd_system_unitdir}/getty.target.wants/serial-getty@$ttydev.service
            install -d ${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@$ttydev.service.d
            cat >${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@$ttydev.service.d/baudrate.conf <<EOF
[Service]
Environment="BAUDRATE=$baudrate"
EOF
            chmod 0644 ${IMAGE_ROOTFS}${systemd_system_unitdir}/serial-getty@$ttydev.service.d/baudrate.conf
	done
    fi
}
ROOTFS_POSTPROCESS_COMMAND += "refkit_image_system_serialgetty; "
