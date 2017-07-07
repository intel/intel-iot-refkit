# Install nss-altfiles, activate it in nsswitch.conf, and move the
# STATELESS_ALTFILES (like passwd) from /etc into
# /usr/lib/defaults/etc.
#
# As we do this after other ROOTFS_POSTPROCESS_COMMAND,
# a default root password makes it into the read-only defaults
# which - if done - is probably intended for debug images.
#
# BEWARE: depends on non-upstream patches, therefore not currently
# used in IoT Refkit and might not even compile.

STATELESS_EXTRA_INSTALL += "nss-altfiles"
STATELESS_POSTPROCESS += " stateless_activate_altfiles;"

stateless_activate_altfiles () {
    # This adds "altfiles" as fallback after "compat" or "files".
    # Relies on nsswitch.conf, which may have been moved already
    # by stateless_activate_nsswitch.
    nsswitch_conf=${IMAGE_ROOTFS}/${sysconfdir}/nsswitch.conf
    if ! [ -e $nsswitch_conf ]; then
        nsswitch_conf=${IMAGE_ROOTFS}${datadir}/defaults/etc/nsswitch.conf
        if ! [ -e $nsswitch_conf ]; then
            bbfatal "nsswitch.conf neither in ${IMAGE_ROOTFS}/${sysconfdir} nor in ${IMAGE_ROOTFS}${datadir}/defaults/etc, require for nss-altfiles."
        fi
    fi
    install -d ${IMAGE_ROOTFS}${datadir}/defaults/etc
    sed -i -e 's/files/files altfiles/' -e 's/compat/compat altfiles/' $nsswitch_conf
}

STATELESS_ALTFILES = "hosts services protocols rpc passwd group shadow gshadow"
STATELESS_MV_ROOTFS += " \
    ${@ ' '.join('%s=${datadir}/defaults/etc/%s' % (x,x) for x in '${STATELESS_ALTFILES}'.split())} \
"

# Do not bail out in "adduser" when /etc/passwd is missing.
STATELESS_SRC_append_pn-busybox = " \
    file://adduser-enable-use-without-etc-passwd.patch None \
"

# Teach shadow about altfiles in /usr/defaults/etc and /usr/defaults/skel.
# For example, setting a password will copy an existing entry from there into /etc.
STATELESS_SRC_append_pn-shadow = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/0003-Do-not-fail-on-missing-files-in-etc-create-them-inst.patch \
    3df4182a48a60dc796a2472812adc1a96146c461e6951646c4baaf47e80ed943 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/0004-Force-use-shadow-even-if-missing.patch \
    8e744ae7779b64d7d9668dc2e9bbf42840dd4ed668b66c6bc22bd88837914bd5 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/0005-Create-dbs-with-correct-permissions.patch \
    cb669ad9e99fba3672733524d4e8671b69a86d303f02d915580fc8af586c2aef \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/0006-Make-usermod-read-altfiles.patch \
    618e1c6b80f03143c614c9338284cae7928b8fed0a726eed6d8b6f38fdb3d5e5 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/stateless-adduser.patch \
    8fff0b1c52712050b3652d26c8a5faf2acc4cf458964c04a6ca1d28d1d928f2e \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/6d0c85ab07e6c7dd399953f3b9fc24947f910bc8/stateless-gpasswd.patch \
    e79a3fac817240ebe3144bab67e7ab5f1247b28b59310a13aa9f2cca33d20451 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/stateless-useradd.patch \
    6f47bd7c5df44a1c4dab1bd102c5a8f0f60cf40fd5c6b4c1afd6f7758f280162 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/d34359528e24569457b8ee8f66d6f2991a291c67/stateless-usermod.patch \
    af825f9c02834eb7ec34f3ef4c1db0dbc2aed985d02e1c3bc6e8deba5f4ebf68 \
"

# Required for setting root password when /etc is empty, because
# otherwise PAM's "is changing the password allowed" check fails,
# leading to a "permission denied" error before the password prompt.
STATELESS_SRC_append_pn-libpam = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/Linux-PAM/b71399c80514afa9411b00aef2be721338a77893/0002-Support-altfiles-locations.patch \
    53636e3e68a60cef4012735d881cffbd3e653b104e55d94d05826c48b8ec9830 \
"
