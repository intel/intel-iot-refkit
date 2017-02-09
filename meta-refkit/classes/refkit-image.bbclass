# Base class for IoT Reference OS Kit images.

REFKIT_IMAGE_EXTRA_INSTALL ?= ""
IMAGE_INSTALL = " \
		kernel-modules \
		linux-firmware \
		packagegroup-core-boot \
                ${ROOTFS_PKGMANAGE_BOOTSTRAP} \
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
    connectivity \
    iotivity \
    nodejs-runtime \
    nodejs-runtime-tools \
    python-runtime \
    sensors \
    tools-debug \
    tools-develop \
    alsa \
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
    smack \
    swupd \
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
        return 'swupd-image'
    else:
        return ''
inherit ${@refkit_swupd_image_class(d)}

# Activate support for updating EFI system partition when using
# both meta-swupd and the EFI kernel+initramfs combo.
IMAGE_INSTALL_append = "${@ ' efi-combo-trigger' if ${REFKIT_USE_DSK_IMAGES} and 'swupd' in d.getVar('IMAGE_FEATURES').split() else '' }"

# Workaround when both Smack and swupd are used:
# Setting a label explicitly on the directory prevents it
# from inheriting other undesired attributes like security.SMACK64TRANSMUTE
# from upper folders (see xattr-images.bbclass for details).
DEPENDS_${PN}_append = " \
    ${@ bb.utils.contains('IMAGE_FEATURES', 'swupd', 'xattr-native', '', d)} \
"
fix_var_lib_swupd () {
    if ${@bb.utils.contains('IMAGE_FEATURES', 'smack', 'true', 'false', d)} &&
       ${@bb.utils.contains('IMAGE_FEATURES', 'swupd', 'true', 'false', d)}; then
        install -d ${IMAGE_ROOTFS}/var/lib/swupd
        setfattr -n security.SMACK64 -v "_" ${IMAGE_ROOTFS}/var/lib/swupd
    fi
}
ROOTFS_POSTPROCESS_COMMAND_append = " fix_var_lib_swupd;"

# Make progress messages from do_swupd_update visible as normal command
# line output, instead of just recording it to the logs. Useful
# because that task can run for a long time without any output.
SWUPD_LOG_FN ?= "bbplain"

# When using the "swupd" image feature, ensure that OS_VERSION is
# set as intended. The default for local build works, but yields very
# unpredictable version numbers (see refkit.conf for details).
#
# For example, build with:
#   BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE OS_VERSION" OS_VERSION=100 bitbake refkit-image-common
#   ...

# Customize priorities of alternative components. See refkit.conf.
#
# In general, Busybox or Toybox are preferred over alternatives.
# The expectation is that either Busybox or Toybox are used, but if
# both get installed, Toybox is used for those commands that it
# provides.
#
# It is still possible to build images with coreutils providing
# core system tools, one just has to remove Toybox/Busybox from
# the image.
export ALTERNATIVE_PRIORITY_BUSYBOX ?= "300"
export ALTERNATIVE_PRIORITY_TOYBOX ?= "301"
export ALTERNATIVE_PRIORITY_BASH ?= "305"

# Both systemd and the efi_combo_updater have problems when
# "mount" is provided by busybox: systemd fails to remount
# the rootfs read/write and the updater segfaults because
# it does not parse the output correctly.
#
# For now avoid these problems by sticking to the traditional
# mount utilities from util-linux.
export ALTERNATIVE_PRIORITY_UTIL_LINUX ?= "305"

# We do not know exactly which util-linux packages will get
# pulled into bundles, so we have to install all of them
# also in the os-core. Alternatively we could try to select
# just mount/umount as overrides for Toybox/Busybox.
IMAGE_INSTALL += "util-linux"

# We need "login" and "passwd" from shadow because:
# - Busybox "login" does not use PAM and thus would require
#   separate patching to support stateless motd (patched
#   in libpam); also the login via getty is different compared
#   to logins via ssh, which is potentially confusing and thus
#   should better be avoided (either no PAM, or PAM everywhere).
# - /dev/tty does not point to the serial console when logging
#   in via getty and using Busybox login, so anything that
#   tries to interact with the user (passwd, ssh) fails.
# - shadow "passwd" creates /etc/shadow if it does not exist
#   yet (required when setting the root password).
export ALTERNATIVE_PRIORITY_SHADOW ?= "305"
IMAGE_INSTALL += "shadow"

# Additional features and packages used by all profile images
# and the refkit-image-common.bb. Not essential for booting
# and thus not included in refkit-image-minimal.bb. Product
# images are expected to pick-and-chose exactly the content
# they neeed instead of using these variables.
REFKIT_IMAGE_FEATURES_COMMON ?= " \
    connectivity \
    ssh-server-openssh \
    iotivity \
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

# We could make bash the login shell for interactive accounts as shown
# below, but that would have to be done also in the os-core and thus
# tools-interactive would have to be set in all swupd images.
# TODO (?): introduce a bash-login-shell image feature?
# ROOTFS_POSTPROCESS_COMMAND_append = "${@bb.utils.contains('IMAGE_FEATURES', 'tools-interactive', ' root_bash_shell; ', '', d)}"
# root_bash_shell () {
#     sed -i -e 's;/bin/sh;/bin/bash;' \
#        ${IMAGE_ROOTFS}${sysconfdir}/passwd \
#        ${IMAGE_ROOTFS}${sysconfdir}/default/useradd
# }

IMAGE_LINGUAS = " "

LICENSE = "MIT"

# See local.conf.sample for explanations.
REFKIT_ROOT_AUTHORIZED_KEYS ?= "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJvLwSo168kOVWAN0a/VzUIK2wQbbg1tLgnZvCYkVnwptSTL3yWcAUspW8sDmCWRzeRKdt/ldOMM/FFjcHGQvZxf+9j98EiWS3c2K+grSdAhSWNun0htFdjqNQgvu08pY7xx78RdUM7QhfgLvkVS/xJBCwUo8952lb1aTHqm8P2DzES4ZwaQ6clEjT9JDf1KRERfIKCBOUwQXkugABdLql0E1kZqliytfGBgLtq0yWvP7yifeeDjFZG5Dz/W40kgOLcp9vG5kxlOe/M9loRlawbObsLV2sB7a7HGD0/5L2z8QPRXpMJVC4RaeeU5RuMjyVzWj5MkfB5yhqT8Mdr/BlIKFOVGdG2WNPszFy6sSHJQSlncwugcv0w68jaGz4wATrlwVHRA2/dTVD+IXgXJHLwt24SXKq69fPST3nHYV5wMH6R2Yjd50LzdvTsH3OQuF9kslPlRjkw2Qi9DA7l8NPiYOw278omHjimHpOVV4891kIC1H+YIuexw0C5h+i1x5+WKaWMjKq2BqNc4Na/9oxOV0KbNlTyhATYGb61cwxj8vK+Z2cpjxxUU7HIGsGELiMt9YcKxZBxkzh0zkSI+TtdfmtzBdOob+fW7Okj8KplQ7b8o77kJKLA4mJnQINqpzp+epHH2S2LxOZdRX1u/huOxXi8Lv+tqoDoFZTyRm4KQ== Intel Hackathon Dev machine"
ROOTFS_POSTPROCESS_COMMAND += "refkit_root_authorized_keys; "
refkit_root_authorized_keys () {
    mkdir ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh
    echo "${REFKIT_ROOT_AUTHORIZED_KEYS}" >>${IMAGE_ROOTFS}${ROOT_HOME}/.ssh/authorized_keys
    chmod -R go-rwx ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh
}

# Do not create ISO images by default, only HDDIMG will be created (if it gets created at all).
NOISO = "1"

inherit image_types_extra

# Replace the default "live" (aka HDDIMG) images with whole-disk images
REFKIT_VM_IMAGE_TYPES ?= ""
IMAGE_FSTYPES_append = " ${REFKIT_VM_IMAGE_TYPES}"

# unconditionally set in x86-base.inc so we just remove it to avoid
# getting image-live.bbclass inherited.
IMAGE_FSTYPES_remove = "live"

# Activate "dsk" image type.
IMAGE_CLASSES += "${@ 'image-dsk' if ${REFKIT_USE_DSK_IMAGES} else ''}"

WKS_FILE = "refkit-directdisk.wks.in"
WIC_CREATE_EXTRA_ARGS += " -D"

# Inherit after setting variables that get evaluated when importing
# the classes. In particular IMAGE_FSTYPES is relevant because it causes
# other classes to be imported.

inherit core-image extrausers image-buildinfo

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

# Mount read-only at first. This gives systemd a chance to run fsck
# and then mount read/write.
APPEND_append = " ro"

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

# Extends the /etc/motd message that is shown on each login.
# Normally it is empty.
REFKIT_EXTRA_MOTD ?= ""
python extra_motd () {
    with open(d.expand('${IMAGE_ROOTFS}${sysconfdir}/motd'), 'a') as f:
        f.write(d.getVar('REFKIT_EXTRA_MOTD', True))
}
ROOTFS_POSTPROCESS_COMMAND += "${@'extra_motd;' if d.getVar('REFKIT_EXTRA_MOTD', True) else ''}"

# Ensure that the os-release file contains values matching the current image creation build.
# We do not want to rebuild the the os-release package for that, because that would
# also trigger image rebuilds when nothing else changed.
#
# FIXME: make this work with both ${IMAGE_ROOTFS}/etc/ and ${IMAGE_ROOTFS}/usr/lib
refkit_image_patch_os_release () {
    sed -i \
        -e 's/distro-version-to-be-added-during-image-creation/${DISTRO_VERSION}/' \
        -e 's/build-id-to-be-added-during-image-creation/${BUILD_ID}/' \
        ${IMAGE_ROOTFS}/etc/os-release
}
refkit_image_patch_os_release[vardepsexclude] = " \
    DISTRO_VERSION \
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
