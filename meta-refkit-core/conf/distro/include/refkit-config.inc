# Miscellaneous settings which may also be useful outside of the IoT
# Reference OS Kit distro itself. To enable this "refkit"
# configuration without switching to the refkit distribution
# completely:
# - include this file
# - add ${REFKIT_DEFAULT_DISTRO_FEATURES} to DISTRO_FEATURES or
#   choose your own defaults
#
# This file does not change the build unless the "refkit-config"
# distro feature is active. In other words, only changes to REFKIT_*
# variables or conditional changes that depend on a refkit-* override
# are allowed here.

# Turns DISTRO_FEATURES into the corresponding overrides.
require conf/distro/include/refkit-overrides.inc

# refkit images distinguish between development and production mode.
# Features that are useful only for development and dangerous
# when used on real devices are not enabled in production mode (example:
# using pre-generated signing keys shipped with the layer).
#
# This has to be set globally because some helper recipes
# like the refkit initramfs need to know about all supported modes.
REFKIT_IMAGE_MODE ??= ""
REFKIT_IMAGE_MODE_VALID ??= "development production"

# OE-core 7355a3c4f665e066925ea6327ac72365ab1f2f39 added a PACKAGECONFIG
# to configure cairo/python3-cairo and enabled it by default. It used to
# be unconditionally disabled and that worked OK for us so we'll restore
# that to avoid additional build dependencies/supported recipes.
PACKAGECONFIG_pn-python3-pygobject_refkit-config = ""

# pango, a graphical text rendering library, is not needed by us.
PACKAGECONFIG_remove_pn-gstreamer1.0-plugins-base_refkit-config = "pango"

# remove readline support from Bluez to reduce GPLv3 dependencies
BAD_RECOMMENDATIONS_append_refkit-config = " bluez5-client"

PACKAGECONFIG_remove_pn-pulseaudio_refkit-config = "avahi"

# Recipe changes not yet upstream which are needed to build images
# with no GPLv3-licenses components. Upstream OE-core changes will
# have this configurable, here it only depends on the "refkit-config"
# distro feature.
DEPENDS_remove_pn-python3_refkit-config = "readline gdbm db"
PACKAGES_remove_pn-python3_refkit-config = "${PN}-readline"
PROVIDES_remove_pn-python3_refkit-config = "${PN}-readline"
RRECOMMENDS_${PN}-core_remove_pn-python3_refkit-config = "${PN}-readline"
RDEPENDS_${PN}-modules_remove_pn-python3_refkit-config = "${PN}-readline"
DEPENDS_remove_pn-python_refkit-config = "readline gdbm db"
PACKAGES_remove_pn-python_refkit-config = "${PN}-readline"
PROVIDES_remove_pn-python_refkit-config = "${PN}-readline"
RRECOMMENDS_${PN}-core_remove_pn-python_refkit-config = "${PN}-readline"
RDEPENDS_${PN}-modules_remove_pn-python_refkit-config = "${PN}-readline"

# build ovmf.secboot (secureboot enabled ovmf BIOS)
PACKAGECONFIG_append_pn-ovmf_refkit-config = " secureboot"

# since we have OpenCL support, turn it on
PACKAGECONFIG_append_pn-opencv_refkit-config = " opencl"
PREFERRED_PROVIDER_virtual/opencl-headers_refkit-config = "opencl-headers"
PREFERRED_PROVIDER_virtual/opencl-headers-cxx_refkit-config = "opencl-headers-cxx"

# Temporary workaround (needs to be fixed in meta-security once the
# necessary patch "net-tools: enable native and nativesdk variant"
# is in OE-core): swtpm_setup.sh needs netstat command.
DEPENDS_append_pn-swtpm-wrappers-native_refkit-config = " net-tools-native"

# The upstream recipe does not start tcsd automatically, but we
# want that because the installer image calls the TPM tools
# without starting tcsd first (it shouldn't have to!), and
# without tcsd already running, the tools just fail. A better
# solution would be socket-activation, but tcsd does not support
# that. Does not matter, tcsd is only installed when needed.
SYSTEMD_AUTO_ENABLE_forcevariable_pn-trousers_refkit-config = "enable"

# only build minimal gstreamer1.0-plugins-bad
PACKAGECONFIG_pn-gstreamer1.0-plugins-bad_refkit-config ?= ""

# usbutils depends directly on libusb1, not the obsolete compatibility. This removes dependency on libusb-compat.
DEPENDS_remove_pn-libgphoto2_refkit-config = "virtual/libusb0"
DEPENDS_append_pn-libgphoto2_refkit-config = " libusb1"

# Depending on the distro features we need certain kernel features. The assumption
# here is that all kernels we use support KERNEL_FEATURES *and* have these
# features.
KERNEL_FEATURES_append_refkit-config = " \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'dm-verity', ' features/device-mapper/dm-verity.scc', '', d) } \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', ' features/tpm/tpm.scc', '', d) } \
"

# Use UEFI-based "dsk" image format for machines supporting UEFI.
# Defined here because it influences several different recipes.
REFKIT_USE_DSK_IMAGES ?= "${@bb.utils.contains_any('MACHINE', 'intel-core2-32 intel-corei7-64 intel-quark', 'True', 'False', d)}"

# When using UEFI-based dsk-style image format created by wic,
# we don't need syslinux and grub-efi and can avoid building them.
DEPENDS_remove_pn-wic-tools_refkit-config = "${@ 'syslinux grub-efi' if oe.types.boolean(d.getVar('REFKIT_USE_DSK_IMAGES') or '0') else '' }"

# systemd is in the default distro features here, but choosing the
# init manager and disabling the sysvinit distro feature has to
# be done in the base configuration, because it cannot be done
# conditionally. See refkit.conf.

REFKIT_DEFAULT_DISTRO_FEATURES = " \
    bluez5 \
    dm-verity \
    luks \
    pam \
    pulseaudio \
    systemd \
    tpm1.2 \
"

# ptests are useful for QA. Enabling them in the distro creates
# additional packages in each recipe that supports ptests and thus
# allows building images with those tests included. Enabling ptests
# should have no effect on normal packages; if there is an effect,
# then that is a bug in the recipe.
REFKIT_DEFAULT_DISTRO_FEATURES += "ptest"

# Enable the distribution-level changes for Computer Vision profile.
# Opengl distro feature is needed for libva.
REFKIT_DEFAULT_DISTRO_FEATURES += "opengl"

# Enable the IPv4/IPv6 firewall configuration.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-firewall"

# Reconfigure several upstream recipes for the computer vision profile.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-computervision"

# Misc recipe changes for the Refkit distro. May also be useful
# for distros not called "refkit" and thus has its own DISTRO_FEATURE and
# "refkit-config" override.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-config"

# Remove currently unsupported distro features from global defaults
REFKIT_DEFAULT_DISTRO_FEATURES_REMOVE += "x11 3g"
