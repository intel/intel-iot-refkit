# This include file moves files from /etc into /usr or removes them
# where the upstream components already support such a change. Except
# for a few minor differences noted below, there should be no change
# in semantic.

# Disable creation of /etc/ld.so.cache in stateless images. The file
# gets already recreated by systemd anyway when booting. Has to be
# done by unsetting LDCONFIGDEPEND (checked by rootfs.py, which
# creates the ld.so.cache) for all IoT Reference OS Kit images, but not the
# refkit-initramfs, so we cannot set it unconditionally.
python () {
    if bb.utils.contains('IMAGE_FEATURES', 'stateless', True, False, d):
        d.setVar('LDCONFIGDEPEND', '')
}

# We can use the pre-generated hwdb.bin as OS default while still
# allowing the creation of an updated version in /etc later on.
# systemd-update-done.service will only run when there is
# something to update in /etc and there are rules in /etc, so
# we clean that up, too.
STATELESS_MV_ROOTFS += " \
    udev/hwdb.bin=${base_libdir}/udev/hwdb.bin \
    udev/hwdb.d=${base_libdir}/udev/hwdb.d \
"

# Anything related to tmpfiles.d in /etc can be considered part of the
# OS and thus be moved to /usr/lib. This includes /etc files which are
# named exactly like existing files under /usr/lib: the ones from
# /usr/lib get overwritten, which preserves the semantic that /etc has
# higher priority.
STATELESS_MV_ROOTFS += " \
    tmpfiles.d=${libdir}/tmpfiles.d \
"

# Similar for udev. There's just a slight change of semantic:
# entries in /etc override those from /run, which they no longer
# do after being moved to /usr/lib - shouldn't matter in practice.
STATELESS_MV_ROOTFS += " \
    udev/rules.d=${base_libdir}/udev/rules.d \
"

# Move /etc/terminfo to /lib/terminfo. That's still going to be
# used before /usr/share/terminfo.
STATELESS_MV_ROOTFS += " \
    terminfo=${base_libdir}/terminfo \
"

# systemd-modules-load.service supports /etc/modules-load.d as well
# as /usr/lib/modules-load.d.
STATELESS_MV_ROOTFS += " \
    modules-load.d=${libdir}/modules-load.d \
"
