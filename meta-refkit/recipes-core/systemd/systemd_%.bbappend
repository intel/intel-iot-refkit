# Prefer systemd way of creating getty@.service symlinks using
# systemd-getty-generator (instead of the Yocto default
# systemd-serialgetty that creates everything in do_install).
PACKAGECONFIG_append = "serial-getty-generator"

#usrmege supported changes
EXTRA_OECONF_append = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', ' --disable-split-usr', ' --enable-split-usr', d)}"
rootprefix = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', '${exec_prefix}', '${base_prefix}', d)}"
