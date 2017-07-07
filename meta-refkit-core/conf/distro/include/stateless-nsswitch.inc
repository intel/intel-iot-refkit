# Enables the use of /etc/nsswitch.conf as local override for
# the defaults in /usr/defaults/etc/nsswitch.conf.
#
# BEWARE: depends on non-upstream patch, therefore not currently
# used in IoT Refkit and might not even compile.

# Beware that creating an /etc/nsswitch.conf without actual entries
# causes a segfault. Reported upstream:
# https://lists.clearlinux.org/pipermail/dev/2017-July/000927.html
STATELESS_SRC_append_pn-glibc = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/glibc/e54b638ef6b5f838e99f1f055474ef2603dfce19/nsswitch-altfiles.patch \
    82b66bc66d935aed845ae51d0ea7188dbc964ae17bda715f7114805ef5cc915d \
"
stateless_activate_nsswitch () {
    # nsswitch.conf gets moved to /usr and is not needed anymore
    # in /etc (see stateless_glibc_altfiles_patch).
    install -d ${IMAGE_ROOTFS}${datadir}/defaults/etc
    mv ${IMAGE_ROOTFS}/${sysconfdir}/nsswitch.conf ${IMAGE_ROOTFS}${datadir}/defaults/etc/nsswitch.conf

    # We must not let systemd re-create it during boot with the systemd defaults.
    if [ -f ${IMAGE_ROOTFS}${libdir}/tmpfiles.d/etc.conf ]; then
        sed -i -e 's;^\(C */etc/nsswitch.conf *.*\);# stateless: \1;' \
            ${IMAGE_ROOTFS}${libdir}/tmpfiles.d/etc.conf
    fi
    rm -f ${IMAGE_ROOTFS}${datadir}/factory/etc/nsswitch.conf
}
STATELESS_POSTPROCESS += " stateless_activate_nsswitch;"
