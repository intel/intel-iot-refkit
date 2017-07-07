# This include file is a proof-of-concept for using systemd's
# tmpfiles.d mechanism to populate /etc from factory defaults.
#
# This approach has several drawbacks:
# - When /etc gets populated this way, the resulting files
#   look to a system update mechanism like OSTree and swupd
#   like they were created locally by an administor, with
#   the result that they won't be touched during a system
#   update even when the factory defaults change.
# - It only works for files which are not needed by
#   by systemd itself during the early boot phase, otherwise
#   the device will be in a different state after the initial
#   boot compared to the state after the first reboot.
#   For example, /etc/hostname gets moved into factory
#   defaults here, but then only becomes effective after
#   a reboot.
#
# Overall it is better to remove the need for files in /etc entirely
# (difficult, often needs patches) or use a system update mechanism
# which has at least some support for /etc (like OSTree, or swupd
# when built in non-stateless mode).

# thermald: upstart init file not needed,
# config file can be in factory.
# TODO: remove the file during packaging
STATELESS_MV_ROOTFS += " \
    init/thermald.conf=factory \
"
STATELESS_MV_ROOTFS += " \
    thermald=factory \
"

# Moving /etc/hostname has the effect that a reboot is required
# before the configured hostname becomes effective again. As not
# much depends on it, that seems a reasonable default.
STATELESS_MV_ROOTFS += " \
    hostname=factory \
"

# By ensuring that udevd starts after tmpfiles, we can move
# its main config file into the factory defaults.
STATELESS_MV_ROOTFS += " \
    udev/udev.conf=factory:systemd-udevd.service \
"

# Move away ld.so.conf and let systemd's factory reset mechanism re-create
# it during boot. For this to work reliably, ldconfig.service must run
# after systemd-tmpfiles-setup.service. Normally they run in parallel.
STATELESS_MV_ROOTFS += " \
    ld.so.conf=factory:ldconfig.service \
"

# systemd/system.conf and systemd/journald.conf can be moved to
# /usr/share/doc if and only if they only contains the default,
# commented out values, because non-default values must already be set
# before these daemons start.
#
# For journald.conf that is problematic, because systemd_232.bb
# changes journald.conf instead of compiling systemd with different
# defaults. That could be changed. For now we ignore those
# modifications and thus accept that the first boot without
# journald.conf will not run quite as it would normally.
#
# Service settings can be moved to /usr because they are part
# of the system.
#
# All remaining systemd config files may or may not have been
# modified and thus get treated as factory defaults.
STATELESS_POSTPROCESS += " stateless_mv_systemd_conf;"
stateless_mv_systemd_conf () {
    for config in system.conf journald.conf; do
        if [ -e ${IMAGE_ROOTFS}${sysconfdir}/systemd/$config ]; then
            if settings=`grep -v -e '^\[.*\]$' -e '^#' -e '^$' -e '^RuntimeMaxUse=' -e '^ForwardToSyslog=' ${IMAGE_ROOTFS}/etc/systemd/$config`; then
                bbfatal "stateless: ${IMAGE_ROOTFS}/etc/systemd/$config contains more than just comments, cannot remove:\n$settings"
            fi
            mkdir -p ${IMAGE_ROOTFS}${datadir}/doc/etc/systemd
            mv ${IMAGE_ROOTFS}${sysconfdir}/systemd/$config ${IMAGE_ROOTFS}${datadir}/doc/etc/systemd
        fi
    done
}
STATELESS_MV_ROOTFS += " \
    systemd/system=${systemd_system_unitdir} \
    xdg/systemd=factory \
    systemd=factory \
"

# Several files in /etc/ssl can become factory defaults.
# /etc/ssl/certs and /etc/ssl itself will be dealt with below.
STATELESS_MV_ROOTFS += " \
    ssl/openssl.cnf=factory \
    ssl/openssl.cnf.real=factory \
    ssl/private=factory \
"

# We could just dump /etc/ssl/certs entirely into the factory
# defaults, but that sounds redundant, because the content
# is already generated from read-only system content. Instead,
# we extend systemd-tmpfiles-setup.service so that it
# also runs update-ca-certificates.
STATELESS_POSTPROCESS += " stateless_rm_etc_ssl_certs;"
stateless_rm_etc_ssl_certs () {
    if [ -e ${IMAGE_ROOTFS}${sbindir}/update-ca-certificates ] &&
       [ -e ${IMAGE_ROOTFS}${systemd_system_unitdir}/systemd-tmpfiles-setup.service ]; then
        echo "ExecStartPost=/bin/sh -c '[ -e ${sysconfdir}/ssl/certs/ca-certificates.crt ] || ${sbindir}/update-ca-certificates'" >>${IMAGE_ROOTFS}${systemd_system_unitdir}/systemd-tmpfiles-setup.service
        rm -rf ${IMAGE_ROOTFS}${sysconfdir}/ssl/certs
        # If empty now, /etc/ssl can be removed, too.
        if rmdir ${IMAGE_ROOTFS}${sysconfdir}/ssl; then
            echo "d ${sysconfdir}/ssl 0755 root root - -" >>${IMAGE_ROOTFS}${libdir}/tmpfiles.d/stateless.conf
        fi
        echo "d ${sysconfdir}/ssl/certs 0755 root root - -" >>${IMAGE_ROOTFS}${libdir}/tmpfiles.d/stateless.conf
    fi
}

# OE chooses the actual resolver (for example, ConnMan vs systemd) at
# build time by symlinking /etc/resolv.conf to the actual .conf file.
# We need to preserve that choice.
STATELESS_MV_ROOTFS += " \
    resolv.conf=factory \
"

# Various things that systemd and journald do not need when they
# start.
STATELESS_MV_ROOTFS += " \
    asound.conf=factory \
    bluetooth=factory \
    busybox.links.nosuid=factory \
    busybox.links.suid=factory \
    ca-certificates.conf=factory \
    dbus-1=factory \
    default=factory \
    environment=factory \
    filesystems=factory \
    grub.d=factory \
    host.conf=factory \
    inputrc=factory \
    issue=factory \
    issue.net=factory \
    libnl=factory \
    mke2fs.conf=factory \
    motd=factory \
    network=factory \
    nftables=factory \
    os-release=factory \
    profile=factory \
    request-key.conf=factory \
    resolv-conf.connman=factory \
    resolv-conf.systemd=factory \
    security=factory \
    ssh=factory \
    skel=factory \
    timestamp=factory \
    udhcpc.d=factory \
    version=factory \
    wpa_supplicant.conf=factory \
"
