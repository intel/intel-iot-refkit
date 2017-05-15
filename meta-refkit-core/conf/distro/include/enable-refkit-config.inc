# In contrast to refkit-config.inc which does not change the
# build configuration, this include file here actually changes
# distro defaults. Use it to emulate how the refkit distro is
# configured. Alternatively, just include refkit-config.inc
# and pick-and-choose features.

require conf/distro/include/refkit-config.inc

# Use systemd exclusively.
DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"
VIRTUAL-RUNTIME_init_manager = "systemd"
VIRTUAL-RUNTIME_initscripts = ""

# Activate default refkit distro features without overwriting the
# defaults from OE-core.
DISTRO_FEATURES_DEFAULT_remove = "${REFKIT_DEFAULT_DISTRO_FEATURES_REMOVE}"
DISTRO_FEATURES ?= "${DISTRO_FEATURES_DEFAULT} ${DISTRO_FEATURES_LIBC} ${REFKIT_DEFAULT_DISTRO_FEATURES}"
