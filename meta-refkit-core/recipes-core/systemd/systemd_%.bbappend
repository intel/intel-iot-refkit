# Prefer systemd way of creating getty@.service symlinks using
# systemd-getty-generator (instead of the Yocto default
# systemd-serialgetty that creates everything in do_install).
PACKAGECONFIG_append_refkit-config = "serial-getty-generator"
