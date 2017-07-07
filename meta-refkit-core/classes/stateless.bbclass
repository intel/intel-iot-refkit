# This moves files out of /etc. It gets applied during
# rootfs creation, so packages do not need to be modified
# (although configuring them differently may lead to
# better results).

# Images are made stateless when "stateless" is in IMAGE_FEATURES.
# By default, that feature is off because it is uncertain which
# images need and support it.
# IMAGE_FEATURES_append_pn-my-stateless-image = " stateless"

# There's a QA check in do_rootfs that warns or errors out when /etc
# is not empty in a stateless image. Because /etc does not actually
# need to be empty (for example, when using OSTree), that check is off
# by default. Valid values: no/warn/error
STATELESS_ETC_CHECK_EMPTY ?= "no"

# A space-separated list of shell patterns. Anything matching a
# pattern is allowed in /etc. Changing this influences the QA check.
STATELESS_ETC_WHITELIST ??= ""

# Determines which directories to keep in /etc although they are
# empty. Normally such directories get removed. Influences the
# QA check and the actual rootfs mangling.
STATELESS_ETC_DIR_WHITELIST ??= ""

# A space-separated list of entries in /etc which need to be moved
# away. Default is to move into ${datadir}/doc/${PN}/etc. The actual
# new name can also be given with old-name=new-name, as in
# "pam.d=${datadir}/pam.d".
#
# "factory" as special target name moves the item under
# /usr/share/factory/etc and adds it to
# /usr/lib/tmpfiles.d/stateless.conf, so systemd will re-recreate
# when missing. This runs after journald has been started and local
# filesystems are mounted, so things required by those operations
# cannot use the factory mechanism.
#
# Gets applied before the normal ROOTFS_POSTPROCESS_COMMANDs.
STATELESS_MV_ROOTFS ??= ""

# A space-separated list of entries in /etc which can be removed
# entirely.
STATELESS_RM_ROOTFS ??= ""

# Semicolon-separated commands which get run after the normal
# ROOTFS_POSTPROCESS_COMMAND, if the image is meant to be stateless.
STATELESS_POSTPROCESS ??= ""

# Extra packages to be installed into stateless images.
STATELESS_EXTRA_INSTALL ??= ""

# STATELESS_SRC can be used to inject source code or patches into
# SRC_URI of a recipe if (and only if) the 'stateless' distro feature is set.
# It is a list of <url> <sha256sum> pairs.
#
# This is similar to:
# SRC_URI_pn-foo = "http://some.example.com/foo.patch;name=foo"
# SRC_URI[foo.sha256sum] = "1234"
#
# Setting the hash sum in SRC_URI has the drawback of namespace
# collisions and triggering a world rebuilds for each varflag change,
# because SRC_URI is modified for all recipes (in contrast to
# normal variables, there's no syntax for setting varflags
# per recipe). STATELESS_SRC avoids that because it gets expanded
# seperately for each recipe.
#
# STATELESS_SRC is useful as an alternative for creating .bbappend
# files. Long-term, all patches included this way should become part
# of the upstream layers and then stateless.bbclass also no longer
# needs to be inherited globally.
STATELESS_SRC = ""


###########################################################################

python () {
    import urllib
    import os
    import string
    src = bb.utils.contains('DISTRO_FEATURES', 'stateless', d.getVar('STATELESS_SRC').split(), [], d)
    while src:
        url = src.pop(0)
        if not src:
            bb.fatal('STATELESS_SRC must contain pairs of url + shasum')
        shasum = src.pop(0)
        name = os.path.basename(urllib.parse.urlparse(url).path)
        name = ''.join(filter(lambda x: x in string.ascii_letters, name))
        d.appendVar('SRC_URI', ' %s;name=%s' % (url, name))
        d.setVarFlag('SRC_URI', '%s.sha256sum' % name, shasum)
}

# "stateless" IMAGE_FEATURES definition
IMAGE_FEATURES[validitems] += "stateless"
FEATURE_PACKAGES_stateless = "${STATELESS_EXTRA_INSTALL}"

# Several post-install scripts modify /etc.
# For example:
# /etc/shells - gets extended when installing a shell package
# /etc/passwd - adduser in postinst extends it
# /etc/systemd/system - has several .wants entries
#
# Instead of completely changing how OE configures images,
# stateless images just take those potentially modified /etc entries
# and makes them part of the read-only system.

# This can be done in different ways:
# 1. permanently move them into /usr and ensure that software looks
#    for entries under both /etc and /usr (example: nss-altfiles
#    for a read-only system user and group database)
# 2. move files in /etc to /usr/share/doc/etc and do not restore
#    them during booting in those cases where a) the file mirrors
#    the builtin defaults of the component using them and b) the
#    component works without the file present.
# 3. use a system update and boot mechanism which creates /etc from
#    system defaults before booting (example: OSTree)
# 4. restore files in /etc during the early boot phase (example:
#    systemd tmpfiles.d)
#
# Case 2 is hard to do in a post-process step, because it's impossible
# to know whether the file in /etc represents builtin defaults. While
# stateless.bbclass has support for this, it's something that is better
# done as part of component packaging.
#
# In case 3 and 4, modifying /etc is possible, but then future system
# updates of the modified files will be ignored.
#
ROOTFS_POSTUNINSTALL_COMMAND_append = "${@ bb.utils.contains('IMAGE_FEATURES', 'stateless', ' stateless_mangle_rootfs;', '', d) }"

python stateless_mangle_rootfs () {
    from oe.utils import execute_pre_post_process
    cmds = d.getVar('STATELESS_POSTPROCESS')
    execute_pre_post_process(d, cmds)

    rootfsdir = d.getVar('IMAGE_ROOTFS', True)
    docdir = rootfsdir + d.getVar('datadir', True) + '/doc/etc'
    whitelist = (d.getVar('STATELESS_ETC_WHITELIST', True) or '').split()
    dirwhitelist = (d.getVar('STATELESS_ETC_DIR_WHITELIST', True) or '').split()
    stateless_mangle(d, rootfsdir, docdir,
                     (d.getVar('STATELESS_MV_ROOTFS', True) or '').split(),
                     (d.getVar('STATELESS_RM_ROOTFS', True) or '').split(),
                     dirwhitelist)
    import os
    etcdir = os.path.join(rootfsdir, 'etc')
    valid = True
    etc_empty = d.getVar('STATELESS_ETC_CHECK_EMPTY')
    etc_empty_allowed = ('no', 'warn', 'error')
    if etc_empty not in etc_empty_allowed:
        bb.fatal('STATELESS_ETC_CHECK_EMPTY = "%s" not one of the valid choices (%s)' %
                 (etc_empty, '/'.join(etc_empty_allowed)))
    if etc_empty != 'no':
        for dirpath, dirnames, filenames in os.walk(etcdir):
            for entry in filenames + [x for x in dirnames if os.path.islink(x)]:
                fullpath = os.path.join(dirpath, entry)
                etcentry = fullpath[len(etcdir) + 1:]
                if not stateless_is_whitelisted(etcentry, whitelist) and \
                   not stateless_is_whitelisted(etcentry, dirwhitelist):
                    bb.warn('stateless: rootfs contains %s' % fullpath)
                    valid = False
        if not valid and etc_empty == 'error':
            bb.fatal('stateless: /etc not empty')
}

def stateless_is_whitelisted(etcentry, whitelist):
    import fnmatch
    for pattern in whitelist:
        if fnmatch.fnmatchcase(etcentry, pattern):
            return True
    return False

def stateless_mangle(d, root, docdir, stateless_mv, stateless_rm, dirwhitelist):
    import os
    import stat
    import errno
    import shutil

    tmpfilesdir = '%s%s/tmpfiles.d' % (root, d.getVar('libdir'))

    # Remove content that is no longer needed.
    for entry in stateless_rm:
        old = os.path.join(root, 'etc', entry)
        if os.path.exists(old) or os.path.islink(old):
            bb.note('stateless: removing %s' % old)
            if os.path.isdir(old) and not os.path.islink(old):
                shutil.rmtree(old)
            else:
                os.unlink(old)

    # Move away files. Default target is docdir, but others can
    # be set by appending =<new name> to the entry, as in
    # tmpfiles.d=libdir/tmpfiles.d. "factory" as target adds
    # the file to those restored by systemd if missing.
    for entry in stateless_mv:
        paths = entry.split('=', 1)
        etcentry = paths[0]
        old = os.path.join(root, 'etc', etcentry)
        if os.path.exists(old) or os.path.islink(old):
            factory = False
            tmpfiles_before = []
            if len(paths) > 1:
                if paths[1] == 'factory' or paths[1].startswith('factory:'):
                    new = root + '/usr/share/factory/etc/' + paths[0]
                    factory = True
                    parts = paths[1].split(':', 1)
                    if len(parts) > 1:
                        tmpfiles_before = parts[1].split(',')
                    (paths[1].split(':', 1)[1:] or [''])[0].split(',')
                else:
                    new = root + paths[1]
            else:
                new = os.path.join(docdir, entry)
            destdir = os.path.dirname(new)
            bb.utils.mkdirhier(destdir)
            # Also handles moving of directories where the target already exists, by
            # moving the content. Symlinks are made relative to the target
            # directory.
            oldtop = old
            moved = []
            def move(old, new):
                bb.note('stateless: moving %s to %s' % (old, new))
                moved.append('/' + os.path.relpath(old, root))
                if os.path.islink(old):
                    link = os.readlink(old)
                    if link.startswith('/'):
                        target = root + link
                    else:
                        target = os.path.join(os.path.dirname(old), link)
                    target = os.path.normpath(target)
                    if not factory and os.path.relpath(target, oldtop).startswith('../'):
                        # Target outside of the root of what we are moving,
                        # so the target must remain the same despite moving
                        # the symlink itself.
                        link = os.path.relpath(target, os.path.dirname(new))
                    else:
                        # Target also getting moved or the symlink will be restored
                        # at its current place, so keep link relative
                        # to where it is now.
                        link = os.path.relpath(target, os.path.dirname(old))
                    if os.path.lexists(new):
                        os.unlink(new)
                    if not factory and (link == '/dev/null' or link.endswith('../dev/null')):
                        # Special case symlink to /dev/null (for example, /etc/tmpfiles.d/home.conf -> /dev/null):
                        # this is used to erase system defaults via local image settings. As we are now merging
                        # with the non-factory system defaults, we can simply erase the file and not
                        # create the symlink.
                        pass
                    else:
                        os.symlink(link, new)
                    os.unlink(old)
                elif os.path.isdir(old):
                    if os.path.exists(new):
                        if not os.path.isdir(new):
                            bb.fatal('stateless: moving directory %s to non-directory %s not supported' % (old, new))
                    else:
                        # TODO (?): also copy xattrs
                        os.mkdir(new)
                        shutil.copystat(old, new)
                        stat = os.stat(old)
                        os.chown(new, stat.st_uid, stat.st_gid)
                    for entry in os.listdir(old):
                        move(os.path.join(old, entry), os.path.join(new, entry))
                    os.rmdir(old)
                else:
                    os.rename(old, new)
            move(old, new)
            if factory:
                # Add new tmpfiles.d entry for the top-level directory.
                with open(os.path.join(tmpfilesdir, 'stateless.conf'), 'a+') as f:
                    if os.path.islink(new):
                        # Symlinks have to be created with a special tmpfiles.d entry.
                        link = os.readlink(new)
                        os.unlink(new)
                        f.write('L /etc/%s - - - - %s\n' % (etcentry, link))
                    else:
                        f.write('C /etc/%s - - - - -\n' % etcentry)
                # We might have moved an entry for which systemd (or something else)
                # already had a tmpfiles.d entry. We need to remove that other entry
                # to ensure that ours is used instead.
                for file in os.listdir(tmpfilesdir):
                    if file.endswith('.conf') and file != 'stateless.conf':
                        with open(os.path.join(tmpfilesdir, file), 'r+') as f:
                            lines = []
                            for line in f.readlines():
                                parts = line.split()
                                if len(parts) >= 2 and parts[1] in moved:
                                    line = '# replaced by stateless.conf entry: ' + line
                                lines.append(line)
                            f.seek(0)
                            f.write(''.join(lines))
                # Ensure that the listed service(s) start after tmpfiles.d setup.
                if tmpfiles_before:
                    service_d_dir = '%s%s/systemd-tmpfiles-setup.service.d' % (root, d.getVar('systemd_system_unitdir'))
                    bb.utils.mkdirhier(service_d_dir)
                    conf_file = os.path.join(service_d_dir, 'stateless.conf')
                    with open(conf_file, 'a') as f:
                        if f.tell() == 0:
                            f.write('[Unit]\n')
                        f.write('Before=%s\n' % ' '.join(tmpfiles_before))

    # Remove /etc if all that's left are directories.
    # Some directories are expected to exists (for example,
    # update-ca-certificates depends on /etc/ssl/certs),
    # so if a directory is white-listed, it does not get
    # removed.
    etcdir = os.path.join(root, 'etc')
    def tryrmdir(path):
        entry = path[len(etcdir) + 1:]
        if stateless_is_whitelisted(entry, dirwhitelist):
           bb.note('stateless: keeping white-listed directory %s' % path)
           return
        bb.note('stateless: removing dir %s (%s not in %s)' % (path, entry, dirwhitelist))
        path_stat = os.stat(path)
        try:
            os.rmdir(path)
            # We may have moved some content into the tmpfiles.d factory,
            # and that then depends on re-creating these directories.
            etcentry = os.path.relpath(path, etcdir)
            if etcentry != '.':
                with open(os.path.join(tmpfilesdir, 'stateless.conf'), 'a') as f:
                    f.write('D /etc/%s 0%o %d %d - -\n' %
                            (etcentry,
                             stat.S_IMODE(path_stat.st_mode),
                             path_stat.st_uid,
                             path_stat.st_gid))
        except OSError as ex:
            bb.note('stateless: removing dir failed: %s' % ex)
            if ex.errno != errno.ENOTEMPTY:
                 raise
    if os.path.isdir(etcdir):
        for root, dirs, files in os.walk(etcdir, topdown=False):
            for dir in dirs:
                path = os.path.join(root, dir)
                if os.path.islink(path):
                    files.append(dir)
                else:
                    tryrmdir(path)
            for file in files:
                bb.note('stateless: /etc not empty: %s' % os.path.join(root, file))
        tryrmdir(etcdir)
