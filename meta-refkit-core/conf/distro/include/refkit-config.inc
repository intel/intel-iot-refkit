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

#########################################################################
# Distro features.
#########################################################################

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


########################################################################
# additional includes
########################################################################

# Turns DISTRO_FEATURES into the corresponding overrides.
require conf/distro/include/refkit-overrides.inc


#########################################################################
# Global distro settings.
#########################################################################

# refkit images distinguish between development and production mode.
# Features that are useful only for development and dangerous
# when used on real devices are not enabled in production mode (example:
# using pre-generated signing keys shipped with the layer).
#
# This has to be set globally because some helper recipes
# like the refkit initramfs need to know about all supported modes.
REFKIT_IMAGE_MODE ??= ""
REFKIT_IMAGE_MODE_VALID ??= "development production"

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

PREFERRED_PROVIDER_virtual/opencl-headers_refkit-config = "opencl-headers"
PREFERRED_PROVIDER_virtual/opencl-headers-cxx_refkit-config = "opencl-headers-cxx"

# remove readline support from Bluez to reduce GPLv3 dependencies
BAD_RECOMMENDATIONS_append_refkit-config = " bluez5-client"

########################################################################
# Changes that can be done via PACKAGECONFIG are meant to be done
# here instead of via .bbappends. SECURITY_* changes go into
# refkit_security_flags.inc. Everything else is in .bbappends,
# except when this could lead to a .bbappend without a corresponding
# .bb file.
#######################################################################

# Prefer systemd way of creating getty@.service symlinks using
# systemd-getty-generator (instead of the Yocto default
# systemd-serialgetty that creates everything in do_install).
PACKAGECONFIG_append_pn-systemd_refkit-config = "serial-getty-generator"

# OE-core 7355a3c4f665e066925ea6327ac72365ab1f2f39 added a PACKAGECONFIG
# to configure cairo/python3-cairo and enabled it by default. It used to
# be unconditionally disabled and that worked OK for us so we'll restore
# that to avoid additional build dependencies/supported recipes.
PACKAGECONFIG_pn-python3-pygobject_refkit-config = ""

# pango, a graphical text rendering library, is not needed by us.
PACKAGECONFIG_remove_pn-gstreamer1.0-plugins-base_refkit-config = "pango"

PACKAGECONFIG_remove_pn-pulseaudio_refkit-config = "avahi"

# build ovmf.secboot (secureboot enabled ovmf BIOS)
PACKAGECONFIG_append_pn-ovmf_refkit-config = " secureboot"

# only build minimal gstreamer1.0-plugins-bad
PACKAGECONFIG_pn-gstreamer1.0-plugins-bad_refkit-config ?= ""

# Enable OpenCL.
PACKAGECONFIG_append_pn-opencv_refkit-config = " opencl"

#########################################################################
# Changes that normally are better suited for a .bbappend have
# to be done here if the corresponding .bb file is not guaranteed
# to be present (i.e. outside of OE-core).
#########################################################################

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

# usbutils depends directly on libusb1, not the obsolete compatibility. This removes dependency on libusb-compat.
DEPENDS_remove_pn-libgphoto2_refkit-config = "virtual/libusb0"
DEPENDS_append_pn-libgphoto2_refkit-config = " libusb1"
