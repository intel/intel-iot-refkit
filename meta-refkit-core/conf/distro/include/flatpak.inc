REFKIT_DEFAULT_DISTRO_FEATURES += " \
    usrmerge \
    pam \
    flatpak \
"

# Enable D-Bus session bus support, needed by flatpak.
PACKAGECONFIG_append_pn-dbus_refkit-config = " user-session"
