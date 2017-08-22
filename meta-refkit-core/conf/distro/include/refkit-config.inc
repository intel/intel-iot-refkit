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

# Reconfigure/patch upstream recipes for the gateway vision profile.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-gateway"

# Reconfigure several upstream recipes for the industrial profile.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-industrial"

# Misc recipe changes for the Refkit distro. May also be useful
# for distros not called "refkit" and thus has its own DISTRO_FEATURE and
# "refkit-config" override.
REFKIT_DEFAULT_DISTRO_FEATURES += "refkit-config"

# Enable OSTree system update support.
REFKIT_DEFAULT_DISTRO_FEATURES += "ostree"

# This is needed for OSTree and flatpack.
REFKIT_DEFAULT_DISTRO_FEATURES += "usrmerge"

# Remove currently unsupported distro features from global defaults
REFKIT_DEFAULT_DISTRO_FEATURES_REMOVE += "x11 3g"

# Turns these DISTRO_FEATURES into overrides of the same name, for use
# in conditional variable operations.
INHERIT += "distrooverrides"
DISTRO_FEATURES_OVERRIDES += " \
    refkit-config \
    refkit-firewall \
    refkit-computervision \
    refkit-gateway \
    refkit-industrial \
"

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
KERNEL_FEATURES_append_df-refkit-config = " \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'dm-verity', ' features/device-mapper/dm-verity.scc', '', d) } \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'tpm1.2', ' features/tpm/tpm.scc', '', d) } \
    ${@ bb.utils.contains('DISTRO_FEATURES', 'refkit-firewall', ' features/nf_tables/nf_tables.scc', '', d) } \
"

# Use UEFI-based "dsk" image format for machines supporting UEFI.
# Defined here because it influences several different recipes.
REFKIT_USE_DSK_IMAGES ?= "${@bb.utils.contains_any('MACHINE', 'intel-core2-32 intel-corei7-64 intel-quark', 'True', 'False', d)}"

PREFERRED_PROVIDER_virtual/opencl-headers_df-refkit-config = "opencl-headers"
PREFERRED_PROVIDER_virtual/opencl-headers-cxx_df-refkit-config = "opencl-headers-cxx"

# remove readline support from Bluez to reduce GPLv3 dependencies
BAD_RECOMMENDATIONS_append_df-refkit-config = " bluez5-client"

# Make ROS use python3 to run its core scripts
ROS_USE_PYTHON3_df-refkit-config = "yes"

########################################################################
# Changes that can be done via PACKAGECONFIG are meant to be done
# here instead of via .bbappends. SECURITY_* changes go into
# refkit_security_flags.inc. Everything else is in .bbappends
# under the "bbappends" directory hierarchy.
#######################################################################

# Prefer systemd way of creating getty@.service symlinks using
# systemd-getty-generator (instead of the Yocto default
# systemd-serialgetty that creates everything in do_install).
PACKAGECONFIG_append_pn-systemd_df-refkit-config = " serial-getty-generator"

# OE-core 7355a3c4f665e066925ea6327ac72365ab1f2f39 added a PACKAGECONFIG
# to configure cairo/python3-cairo and enabled it by default. It used to
# be unconditionally disabled and that worked OK for us so we'll restore
# that to avoid additional build dependencies/supported recipes.
PACKAGECONFIG_pn-python3-pygobject_df-refkit-config = ""

# pango, a graphical text rendering library, is not needed by us.
PACKAGECONFIG_remove_pn-gstreamer1.0-plugins-base_df-refkit-config = "pango"

PACKAGECONFIG_remove_pn-pulseaudio_df-refkit-config = "avahi"

# build ovmf.secboot (secureboot enabled ovmf BIOS)
PACKAGECONFIG_append_pn-ovmf_df-refkit-config = " secureboot"

# only build minimal gstreamer1.0-plugins-bad
PACKAGECONFIG_pn-gstreamer1.0-plugins-bad_df-refkit-config ?= ""

# Enable OpenCL and DNN modules.
PACKAGECONFIG_append_pn-opencv_df-refkit-config = " opencl dnn"

#########################################################################
# Changes that normally are better suited for a .bbappend have
# to be done here if the corresponding .bb file is not guaranteed
# to be present (i.e. outside of OE-core).
#########################################################################

# Use nftables instead of iptables.
PACKAGECONFIG_remove_pn-connman_df-refkit-config = "iptables"
PACKAGECONFIG_append_pn-connman_df-refkit-config = " nftables"

# Use ssl instead of gnutls
PACKAGECONFIG_remove_pn-curl_df-refkit-config = "gnutls"
PACKAGECONFIG_append_pn-curl_df-refkit-config = " ssl"

#remove gtk dependency from opencv
PACKAGECONFIG_remove_pn-opencv_df-refkit-config = "gtk"
