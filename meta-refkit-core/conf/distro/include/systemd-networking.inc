# For some profiles it's enough to have systemd's networking capabilities only.
# Include this file into your local.conf or into a profile specific distro
# config to enable them.
PACKAGECONFIG_append_pn-systemd = " networkd resolved"
