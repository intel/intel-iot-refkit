# Check that the user has explicitly chosen how to build images.
REFKIT_IMAGE_BUILD_MODE_SELECTED ?= ""
addhandler refkit_sanity_check_eventhandler
refkit_sanity_check_eventhandler[eventmask] = "bb.event.SanityCheck"
python refkit_sanity_check_eventhandler() {
    if not d.getVar('REFKIT_IMAGE_BUILD_MODE_SELECTED', True):
        import os
        bb.fatal('''"conf/local.conf" must be explicitly edited to select between building
production and development images. More details about the choices in that file.''')
}

# /run, /proc, /var/volatile and /dev only get mounted at runtime.
REFKIT_QA_IMAGE_SYMLINK_WHITELIST = " \
    /dev/null \
    /proc/mounts \
    /run/lock \
    /run/resolv.conf \
    /var/volatile/log \
    /var/volatile/tmp \
    ${@bb.utils.contains('IMAGE_FEATURES', 'ostree', \
      '../run ../run/lock var/mnt var/home sysroot/tmp sysroot/ostree', \
      '' , d)} \
"

# Additional image checks.
python refkit_qa_image () {
    qa_sane = True

    rootfs   = d.getVar("IMAGE_ROOTFS", True)
    distro   = d.getVar("DISTRO")
    mlprefix = d.getVar('MLPREFIX')
    target   = (d.getVar('TARGET_ARCH_MULTILIB_ORIGINAL') if mlprefix \
                    else d.getVar('TARGET_ARCH'))

    ostree = bb.utils.contains("IMAGE_FEATURES", "ostree", True, False, d) and \
                 d.getVar("IMAGE_BASENAME").endswith('ostree')

    if ostree:
        rootfs = rootfs + '.ostree'
        ostree_dir = rootfs + "/ostree"
        ostree_repo = rootfs + "/ostree/repo/"
        cmd = "ostree --repo=%s/repo rev-parse %s:%s/%s/standard" % \
            (ostree_dir, distro, distro, target)
        (status, sha256) = oe.utils.getstatusoutput(cmd)
        if status != 0:
            bb.fatal("Failed to resolve OSTree deploy path.")
        ostree_root = '%s/deploy/%s/deploy/%s.0' % (ostree_dir, distro, sha256)
        print('cmd: %s, status:%d, sha256:%s\n' % (cmd, status, sha256))
        print('ostree_root: %s\n' % ostree_root)
    else:
        ostree_root = ""
        ostree_repo = ""

    def resolve_links(target, root):
        if ostree and target in whitelist:
            return target
        if not target.startswith('/'):
            target = os.path.normpath(os.path.join(root, target))
        else:
            # Absolute links are in fact relative to the rootfs.
            # Can't use os.path.join() here, it skips the
            # components before absolute paths.
            target = os.path.normpath(rootfs + target)
        if ostree and target.startswith(rootfs + '/usr/'):
            reloc = ostree_root + '/usr/' + target.split(rootfs + '/usr/')[1]
            print('relocated %s -> %s\n' % (target, reloc))
            target = reloc

        if os.path.islink(target):
            if target in whitelist:
                return target
            root = os.path.dirname(target)
            old = target
            target = os.readlink(target)
            bb.warn('symlink %s resolved to %s\n' % (old, target))
            if target in whitelist:
                return target
            target = resolve_links(target, root)
        return target

    # Check for dangling symlinks. One common reason for them
    # in swupd images is update-alternatives where the alternative
    # that gets chosen in the mega image then is not installed
    # in a sub-image.
    #
    # Some allowed cases are whitelisted.
    whitelist = d.getVar('REFKIT_QA_IMAGE_SYMLINK_WHITELIST', True).split()
    for root, dirs, files in os.walk(rootfs):
        for entry in files + dirs:
            path = os.path.join(root, entry)
            if ostree and path.startswith(ostree_repo):
                continue
            if os.path.islink(path):
                target = os.readlink(path)
                final_target = resolve_links(target, root)
                if not os.path.exists(final_target) and not final_target[len(rootfs):] in whitelist and not target in whitelist:
                    bb.error("Dangling symlink: %s -> %s -> %s does not resolve to a valid filesystem entry." %
                             (path, target, final_target))
                    if not ostree:
                        qa_sane = False

    if not qa_sane:
        bb.fatal("Fatal QA errors found, failing task.")
}

do_image[postfuncs] += "refkit_qa_image"
