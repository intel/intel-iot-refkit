# Moves login-related files from /etc to /usr/share/doc/etc. Relies
# on sane defaults in the binaries which read these files. Don't use
# this include file if the distro actually depends on non-standard
# settings in those files!
#
# BEWARE: depends on non-upstream patch, therefore not currently
# used in IoT Refkit and might not even compile.

STATELESS_MV_ROOTFS += " \
    login.defs \
    securetty \
    shells \
"

# Enable logins without /etc/login.defs.
STATELESS_SRC_append_pn-shadow = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/0001-Do-not-bail-out-on-missing-login.defs.patch \
    7bf3f3df680fe1515deca2e7bc1715759616f101156650c95172366a79817662 \
    https://raw.githubusercontent.com/clearlinux-pkgs/shadow/2aae81d2f493e340f454e6888c79f71c0414726c/stateless-login.patch \
    3bb9bc5936111fac2cfd9723423281c98533740c5ca564152488d9ba33021cc5 \
"

# Use /usr/share/pam.d instead of /usr/lib/pam.d (for the sake of consistency?)
# and move /etc files to it. We must prevent systemd from re-creating the files
# from its own builtin copies.
STATELESS_SRC_append_pn-libpam = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/Linux-PAM/b71399c80514afa9411b00aef2be721338a77893/0001-libpam-Keep-existing-pamdir-for-transition.patch \
    25761101f785878dc7817344f484f670de5723df2eccc17dad9236af446cb890 \
"
STATELESS_MV_ROOTFS += "pam.d=${datadir}/pam.d"
STATELESS_POSTPROCESS += " stateless_rm_systemd_pamd_factory;"
stateless_rm_systemd_pamd_factory () {
    rm -rf ${IMAGE_ROOTFS}${datadir}/factory/etc/pam.d
    if [ -f ${IMAGE_ROOTFS}${libdir}/tmpfiles.d/etc.conf ]; then
        sed -i -e 's;^\(C */etc/pam.d *.*\);# stateless: \1;' \
            ${IMAGE_ROOTFS}${libdir}/tmpfiles.d/etc.conf
    fi
}

# Allow logins without /etc/login.defs, /etc/securetty or /etc/shells.
STATELESS_SRC_append_pn-libpam = " \
    https://raw.githubusercontent.com/clearlinux-pkgs/Linux-PAM/0681d308b660919e6a7ee71be41397dbc8516519/0003-pam_env-Only-report-non-ENOENT-errors-for-env-file.patch \
    5b6866931e70524ed29cc2b2f5abf31f732658441207d441ec00cbcb9f04833e \
    https://raw.githubusercontent.com/clearlinux-pkgs/Linux-PAM/aa0bf6295ec8faa96cad1094806a545aae03247e/0004-pam_shells-Support-a-stateless-configuration-by-defa.patch \
    35d3ca298728aab229b1b82e01ae6b7d0f7be11b0e71c7d18d92ebc8069087aa \
"

# TODO (?): avoid log entry about "Couldn't open /etc/securetty" each time
# pam_securetty is used. Written for libpam 1.2.1, does not apply to 1.3.0
# because the code was modified. Not particularly important as pam_securetty
# seems unused in OE-core.
#SRC_URI_append_pn-libpam = " \
#    https://raw.githubusercontent.com/clearlinux-pkgs/Linux-PAM/0681d308b660919e6a7ee71be41397dbc8516519/0001-pam_securetty-Do-not-report-non-fatal-documented-beh.patch \
#"
