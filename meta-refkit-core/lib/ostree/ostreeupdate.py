import bb
import oe.path

import glob
import hashlib
import os.path
import shutil
import string
import subprocess

VARIABLES = (
    'IMAGE_ROOTFS',
    'OSTREE_BRANCHNAME',
    'OSTREE_COMMIT_SUBJECT',
    'OSTREE_REPO',
    'OSTREE_GPGDIR',
    'OSTREE_GPGID',
    'OSTREE_OS',
    'OSTREE_REMOTE',
    'OSTREE_BARE',
    'OSTREE_ROOTFS',
    'OSTREE_SYSROOT',
)

class OSTreeUpdate(string.Formatter):
    """
    Create an OSTree-enabled version of an image rootfs, using an intermediate
    per-image OSTree bare-user repository. Optionally export the content
    of this repository into HTTP-exportable archive-z2 OSTree repository
    which clients can use to pull the image in as an OSTree upgrade.
    """

    WHITESPACES_ALLOWED = (
        'OSTREE_COMMIT_SUBJECT',
        )

    def __init__(self, d):
        for var in VARIABLES:
            value = d.getVar(var)
            if var not in self.WHITESPACES_ALLOWED:
                for c in '\n\t ':
                    if c in value:
                        bb.fatal('%s=%s is not allowed to contain whitespace' % (var, value))
            setattr(self, var, value)

        self.gpg_sign = ''
        if self.OSTREE_GPGID:
            if self.OSTREE_GPGDIR:
                self.gpg_sign += self.format(' --gpg-homedir={OSTREE_GPGDIR}')
            self.gpg_sign += self.format(' --gpg-sign={OSTREE_GPGID}')

    def get_value(self, key, args, kwargs):
        """
        This class inherits string.Formatter and thus has self.format().
        We extend the named field lookup so that object attributes and thus
        the variables above can be used directly.
        """
        if isinstance(key, str) and key not in kwargs:
            return getattr(self, key)
        else:
            return super().get_value(key, args, kwargs)


    def run_ostree(self, command, *args, **kwargs):
        cmd = 'ostree ' + self.format(command, *args, **kwargs)
        bb.debug(1, 'Running: {0}'.format(cmd))
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
        return output

    def copy_sysroot(self):
        """
        Seed the OSTree sysroot with the pristine one.
        """
        bb.note(self.format('Copying pristine rootfs {IMAGE_ROOTFS} to OSTree sysroot {OSTREE_SYSROOT} ...'))
        oe.path.copyhardlinktree(self.IMAGE_ROOTFS, self.OSTREE_SYSROOT)

    def copy_kernel(self):
        """
        Copy and checksum kernel, initramfs, and the UEFI app in place for OSTree.
        TODO: why?
        """

        uefidir = os.path.join(self.IMAGE_ROOTFS, 'boot')
        uefibootdir = os.path.join(uefidir, 'EFI', 'BOOT')
        uefiinternalbootdir = os.path.join(uefidir, 'EFI_internal_storage', 'BOOT')
        uefiappname = glob.glob(os.path.join(uefibootdir, 'boot*.efi'))
        if len(uefiappname) != 1:
            bb.fatal(self.format('Ambiguous UEFI app in {0}: {1}', uefibootdir, uefiappname))
        uefiappname = os.path.basename(uefiappname[0])

        ostreeboot = os.path.join(self.OSTREE_SYSROOT, 'usr', 'lib', 'ostree-boot')
        bb.note(self.format('Copying and checksumming UEFI combo app(s) {0} into OSTree sysroot {1} ...', uefiappname, ostreeboot))
        bb.utils.mkdirhier(ostreeboot)
        def copy_app(src, dst):
            with open(src, 'rb') as f:
                data = f.read()
                chksum = hashlib.sha256(data).hexdigest()
            with open(dst + '-' + chksum, 'wb') as f:
                f.write(data)
            shutil.copystat(src, dst + '-' + chksum)
            return chksum

        # OSTree doesn't care too much about the actual checksums on kernel
        # and initramfs. We use the same checksum derived from the UEFI combo
        # app for all parts related to it.
        chksum = copy_app(os.path.join(uefibootdir, uefiappname),
                          os.path.join(ostreeboot, uefiappname + '.ext'))
        copy_app(os.path.join(uefiinternalbootdir, uefiappname),
                 os.path.join(ostreeboot, uefiappname + '.int'))

        # OSTree expects to find kernel and initramfs, so we provide it
        # although the files are not used.
        # TODO: does it really make sense to put the real content there?
        # It's not going to get used.
        bb.note('Extracting and checksumming kernel, initramfs for ostree...')
        kernel = os.path.join(ostreeboot, 'vmlinuz')
        initrd = os.path.join(ostreeboot, 'initramfs')
        # TODO: where does objcopy come from?
        #subprocess.check_output('objcopy --dump-section .linux=%s --dump-section .initrd=%s %s' %
        #                        (kernel, initrd, os.path.join(uefibootdir, uefiappname)))
        # os.rename(kernel, kernel + '-' + chksum)
        # os.rename(initrd, initrd + '-' + chksum)

        # For now just create dummy files.
        open(kernel + '-' + chksum, 'w').close()
        open(initrd + '-' + chksum, 'w').close()

    def ostreeify_sysroot(self):
        """
        Mangle sysroot into an OSTree-compatible layout.
        """
        # Note that everything created/shuffled here will end up getting
        # relocated under the ostree deployment directory for the image
        # we're building. Everything that needs to get created relative in the
        # to the final physical rootfs should be done in finalize_sysroot.
        bb.note('* Shuffling sysroot to OSTree-compatible layout...')

        # The OSTree deployment model requires the following directories
        # and symlinks in place:
        #
        #     /sysroot: the real physical rootfs bind-mounted here
        #     /sysroot/ostree: ostree repo and deployments ('checkouts')
        #     /ostree: symlinked to /sysroot/ostree for consistent access
        #
        # Additionally the deployment model suggests setting up deployment
        # root symlinks for the following:
        #
        #     /home -> /var/home (further linked -> /sysroot/home)
        #     /opt -> /var/opt
        #     /srv -> /var/srv
        #     /root -> /var/roothome
        #     /usr/local -> /var/local
        #     /mnt -> /var/mnt
        #     /tmp -> /sysroot/tmp
        #
        # In this model, /var can be a persistent second data partition.
        # We just use one partition, so instead we have:
        #
        #     /boot = mount point for persistent /boot directory in the root partition
        #     /var = mount point for persistent /ostree/deploy/refkit/var
        #     /home = mount point for persistent /home directory in the root partition
        #     /mnt = symlink to var/mnt
        #     /tmp = symlink to sysroot/tmp (persistent)
        #
        # Additionally,
        #     /etc is moved to /usr/etc as the default config

        sysroot = os.path.join(self.OSTREE_SYSROOT, 'sysroot')
        bb.utils.mkdirhier(sysroot)
        os.symlink('sysroot/ostree', os.path.join(self.OSTREE_SYSROOT, 'ostree'))

        for dir, link in (
                ('boot', None),
                ('var', None),
                ('home', None),
                ('mnt', 'var/mnt'),
                ('tmp', 'sysroot/tmp'),
        ):
            path = os.path.join(self.OSTREE_SYSROOT, dir)
            if os.path.isdir(path):
                shutil.rmtree(path)
            if link is None:
                bb.utils.mkdirhier(path)
            else:
                os.symlink(link, path)

        # Preserve read-only copy of /etc for OSTree's three-way merge.
        os.rename(os.path.join(self.OSTREE_SYSROOT, 'etc'),
                  os.path.join(self.OSTREE_SYSROOT, 'usr', 'etc'))

    def prepare_sysroot(self):
        """
        Prepare a rootfs for committing into an OSTree repository.
        """

        if os.path.isdir(self.OSTREE_SYSROOT):
            bb.note(self.format('OSTree sysroot {OSTREE_SYSROOT} already exists, nuking it...'))
            shutil.rmtree(self.OSTREE_SYSROOT)

        bb.note(self.format('Preparing OSTree sysroot {OSTREE_SYSROOT} ...'))
        self.copy_sysroot()
        self.copy_kernel()
        self.ostreeify_sysroot()

    def populate_repo(self):
        """
        Populate primary OSTree repository (bare-user mode) with the given sysroot.
        """
        bb.note(self.format('Populating OSTree primary repository {OSTREE_BARE} ...'))

        if os.path.isdir(self.OSTREE_BARE):
            shutil.rmtree(self.OSTREE_BARE)
        bb.utils.mkdirhier(self.OSTREE_BARE)
        self.run_ostree('--repo={OSTREE_BARE} init --mode=bare-user')
        self.run_ostree('--repo={OSTREE_BARE} commit '
                         '{gpg_sign} '
                         '--tree=dir={OSTREE_SYSROOT} '
                         '--branch={OSTREE_BRANCHNAME} '
                         '--subject="{OSTREE_COMMIT_SUBJECT}"')
        output = self.run_ostree('--repo={OSTREE_BARE} summary -u')
        bb.note(self.format('OSTree primary repository {OSTREE_BARE} summary:\n{0}', output))


    def checkout_sysroot(self):
        """
        Replicate the ostree repository into the OSTree rootfs and make a checkout/deploy.
        """
        if os.path.isdir(self.OSTREE_ROOTFS):
            shutil.rmtree(self.OSTREE_ROOTFS)

        bb.note(self.format('Initializing OSTree rootfs {OSTREE_ROOTFS} ...'))
        bb.utils.mkdirhier(self.OSTREE_ROOTFS)
        self.run_ostree('admin --sysroot={OSTREE_ROOTFS} init-fs {OSTREE_ROOTFS}')
        self.run_ostree('admin --sysroot={OSTREE_ROOTFS} os-init {OSTREE_OS}')

        bb.note(self.format('Replicating primary OSTree repository {OSTREE_BARE} branch {OSTREE_BRANCHNAME} into OSTree rootfs {OSTREE_ROOTFS} ...'))
        self.run_ostree('--repo={OSTREE_ROOTFS}/ostree/repo pull-local --remote=updates {OSTREE_BARE} {OSTREE_BRANCHNAME}')

        bb.note('Deploying sysroot from OSTree sysroot repository...')
        self.run_ostree('admin --sysroot={OSTREE_ROOTFS} deploy --os={OSTREE_OS} updates:{OSTREE_BRANCHNAME}')

        # OSTree initialized var for our OS, but we want the original rootfs content instead.
        src = os.path.join(self.IMAGE_ROOTFS, 'var')
        dst = os.path.join(self.OSTREE_ROOTFS, 'ostree', 'deploy', self.OSTREE_OS, 'var')
        bb.note(self.format('Copying /var from rootfs to OSTree rootfs as {} ...', dst))
        shutil.rmtree(dst)
        oe.path.copyhardlinktree(src, dst)

        if self.OSTREE_REMOTE:
            bb.note(self.format('Setting OSTree remote to {OSTREE_REMOTE} ...'))
            self.run_ostree('remote add --repo={OSTREE_ROOTFS}/ostree/repo '
                             '--gpg-import={OSTREE_GPGDIR}/pubring.gpg '
                             'updates {OSTREE_REMOTE}')


    def finalize_sysroot(self):
        """
        Finalize the physical root directory after the ostree checkout.
        """
        bb.note(self.format('Creating EFI mount point /boot/efi in OSTree rootfs {OSTREE_ROOTFS} ...'))
        bb.utils.mkdirhier(os.path.join(self.OSTREE_ROOTFS, 'boot', 'efi'))

        bb.note(self.format('Copying pristine rootfs {IMAGE_ROOTFS}/home to OSTree rootfs {OSTREE_ROOTFS} ...'))
        oe.path.copyhardlinktree(os.path.join(self.IMAGE_ROOTFS, 'home'),
                                 os.path.join(self.OSTREE_ROOTFS, 'home'))


    def prepare_rootfs(self):
        """
        Create the intermediate, bare repo and a fully functional rootfs for the target device
        where the current build is deployed.
        """
        self.prepare_sysroot()
        self.populate_repo()
        self.checkout_sysroot()
        self.finalize_sysroot()


    def export_repo(self):
        """
        Export data from a primary OSTree repository to the given (archive-z2) one.
        """

        bb.note(self.format('Exporting primary repository {OSTREE_BARE} to export repository {OSTREE_REPO}...'))
        if not os.path.isdir(self.OSTREE_REPO):
            bb.note("Initializing repository %s for exporting..." % self.OSTREE_REPO)
            bb.utils.mkdirhier(self.OSTREE_REPO)
            self.run_ostree('--repo={OSTREE_REPO} init --mode=archive-z2')

        self.run_ostree('--repo={OSTREE_REPO} pull-local --remote={OSTREE_OS} {OSTREE_BARE} {OSTREE_BRANCHNAME}')
        self.run_ostree('--repo={OSTREE_REPO} commit {gpg_sign} --branch={OSTREE_BRANCHNAME} --tree=ref={OSTREE_OS}:{OSTREE_BRANCHNAME}')
        self.run_ostree('--repo={OSTREE_REPO} summary {gpg_sign} -u')
