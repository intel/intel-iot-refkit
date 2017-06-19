REFKIT_DEFAULT_DISTRO_FEATURES += " \
    usrmerge \
    systemd \
    pam \
    flatpak \
"

# Enable D-Bus session bus support, needed by flatpak.
PACKAGECONFIG_append_pn-dbus_df-refkit-config = " user-session"
