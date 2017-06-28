# This file defines some common test scenarios for system
# updates. Actual tests for certain update mechanisms need to inherit
# SystemUpdateTest and implement the stubs.

from oeqa.selftest.case import OESelftestTestCase
from oeqa.utils.commands import runCmd, bitbake, get_bb_var, get_bb_vars, runqemu
import oe.path

import base64
import pathlib
import pickle

class SystemUpdateModify(object):
    """
    A helper class which will be used to make changes to the rootfs.
    Each SystemUpdateBase instance needs one such helper instance.
    Derived helper classes have to be simple enough such that they
    can be pickled.
    """

    # Changes that can be tested alone or in combination with each other.
    # Implemented by do_<update> and verified in verify_<update> methods,
    # plus .bbappend changes in modify_image_build().
    UPDATES = [
        'etc',
        'files',
        'home',
        'kernel',
        'var',
    ]

    # Some /etc config files that we can modify by appending
    # commented out lines. We also apply special changes:
    # - replacing file with symlink
    # - modifying file locally before update which then must
    #   be used instead of the updated system file
    ETC_FILES = [
        ( 'nsswitch.conf', 'edit' ),
        ( 'ssl/openssl.cnf', 'symlink' ),
        ( 'ssh/sshd_config', None ),
    ]

    def modify_image_build(self, testname, updates, is_update):
        """
        Returns additional settings that get stored in a .bbappend
        of the test image.
        """
        bbappend = []
        if 'kernel' in updates:
            bbappend.append('APPEND_append = " modify_kernel_test=%s"' % ('updated' if is_update else 'original'))
        return '\n'.join(bbappend)

    def modify_kernel(self, testname, is_update, rootfs):
        """
        Patch the kernel in an existing rootfs. Called during rootfs construction,
        once for the initial image (is_update=False) and once for the update.
        Instead of patching the file, changing build configurations with modify_build()
        is also possible.
        """
        pass

    def verify_kernel(self, testname, is_update, qemu, test):
        """
        Sanity check kernel and boot parameters before and after update.
        """
        cmd = "cat /proc/cmdline"
        status, output = qemu.run_serial(cmd)
        test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        test.assertIn('modify_kernel_test=%s' % ('updated' if is_update else 'original'),
                      output)

    def modify_files(self, testname, is_update, rootfs):
        """
        Simulate simple adding, removing and modifying of files under /usr/bin.
        """
        testdir = os.path.join(rootfs, 'usr', 'bin')
        if not is_update:
            pathlib.Path(os.path.join(testdir, 'modify_files_remove_me')).touch()
            pathlib.Path(os.path.join(testdir, 'modify_files_update_me')).touch()
        else:
            with open(os.path.join(testdir, 'modify_files_update_me'), 'w') as f:
                f.write('updated\n')
            pathlib.Path(os.path.join(testdir, 'modify_files_was_added')).touch()

    def verify_files(self, testname, is_update, qemu, test):
        """
        Sanity check files before and after update.
        """
        cmd = 'ls -1 /usr/bin/modify_files_*'
        status, output = qemu.run_serial(cmd)
        test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        if not is_update:
            test.assertEqual(output, '/usr/bin/modify_files_remove_me\r\n/usr/bin/modify_files_update_me')
        else:
            test.assertEqual(output, '/usr/bin/modify_files_update_me\r\n/usr/bin/modify_files_was_added')
            cmd = 'cat /usr/bin/modify_files_update_me'
            status, output = qemu.run_serial(cmd)
            test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            test.assertEqual(output, 'updated')

    def modify_etc(self, testname, is_update, rootfs):
        """
        If there are files in /etc, then it should be possible to update
        them as part of a system update.
        """
        if is_update:
            for file, operation in self.ETC_FILES:
                path = os.path.join(rootfs, 'etc', file)
                with open(path, 'ab') as f:
                    f.write(b'\n# system update test\n')
                if operation == 'symlink':
                    os.rename(path, path + '.real')
                    os.symlink(os.path.basename(file) + '.real', path)

    def verify_etc(self, testname, is_update, qemu, test):
        if not is_update:
            for file, operation in self.ETC_FILES:
                if operation == 'edit':
                    cmd = "echo '# edited locally' >>/etc/%s" % file
                    status, output = qemu.run_serial(cmd)
                    test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        else:
            for file, operation in self.ETC_FILES:
                cmd = "tail -1 /etc/%s" % file
                status, output = qemu.run_serial(cmd)
                test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
                expected = '# edited locally' if operation == 'edit' else '# system update test'
                test.assertEqual(output, expected, msg='%s not handled correctly' % file)

    def modify_home(self, testname, is_update, rootfs):
        """
        Full images take the /home content from the rootfs,
        but later /home does not get updated.
        """
        with open(os.path.join(rootfs, 'home', 'root', 'home-test-file'), 'w') as f:
            f.write('update: hello world\n' if is_update else 'original: hello world\n')

    def verify_home(self, testname, is_update, qemu, test):
        cmd = "cat /home/root/home-test-file"
        status, output = qemu.run_serial(cmd)
        test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        test.assertEqual(output, 'original: hello world')

    def modify_var(self, testname, is_update, rootfs):
        """
        Full images take the /var content from the rootfs,
        but later /var does not get updated.
        """
        with open(os.path.join(rootfs, 'var', 'var-test-file'), 'w') as f:
            f.write('update: hello world\n' if is_update else 'original: hello world\n')

    def verify_var(self, testname, is_update, qemu, test):
        cmd = "cat /var/var-test-file"
        status, output = qemu.run_serial(cmd)
        test.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        test.assertEqual(output, 'original: hello world')

    def _do_modifications(self, d, testname, updates, is_update):
        """
        This code will run as part of a ROOTFS_POSTPROCESS_COMMAND.
        """
        rootfs = d.getVar('IMAGE_ROOTFS')
        for update in updates:
            bb.note('%s: running modify_%s' % (testname, update))
            getattr(self, 'modify_' + update)(testname, is_update, rootfs)

class SystemUpdateBase(OESelftestTestCase):
    """
    Base class for system update testing.
    """

    # The image that will get built, booted and updated.
    IMAGE_PN = 'core-image-minimal'

    # The .bbappend name which matches IMAGE_PN.
    # For example, OSTree might build and boot "core-image-minimal-ostree",
    # but the actual image recipe is "core-image-minimal" and thus
    # we would need "core-image-minimal.bbappend". Also allows to handle
    # cases where the bbappend file name must have a wildcard.
    IMAGE_BBAPPEND = 'core-image-minimal.bbappend'

    # Additional image settings that will get written into the IMAGE_BBAPPEND.
    IMAGE_CONFIG = ''

    # Expected to be replaced by derived class.
    IMAGE_MODIFY = SystemUpdateModify()

    def boot_image(self, overrides):
        """
        Calls runqemu() such that commands can be started via run_serial().
        Derived classes need to replace with something that adds whatever
        other parameters are needed or useful.
        """
        return runqemu(self.IMAGE_PN, discard_writes=False, overrides=overrides)

    def update_image(self, qemu):
        """
        Triggers the actual update, optionally requesting a reboot by returning True.
        """
        self.fail('not implemented')

    def verify_image(self, testname, is_update, qemu, updates):
        """
        Verify content of image before and after the update.
        """
        for update in updates:
            getattr(self.IMAGE_MODIFY, 'verify_' + update)(testname, is_update, qemu, self)

    def do_update(self, testname, updates):
        """
        Builds the image, makes a copy of the result, rebuilds to produce
        an update with configurable changes, boots the original image, updates it,
        reboots and then checks the updated image.

        'update' is a list of modify_* function names which make the actual changes
        (adding, removing, modifying files or kernel) that are part of the tests.
        """

        def create_image_bbappend(is_update):
            """
            Creates an IMAGE_BBAPPEND which contains the pickled modification code.
            A .bbappend is used because it can contain code and is guaranteed to be
            applied also to image variants.
            """

            self.track_for_cleanup(self.IMAGE_BBAPPEND)
            with open(self.IMAGE_BBAPPEND, 'w') as f:
                f.write('''
python system_update_test_modify () {
    import base64
    import pickle

    code = %s
    do_modifications = pickle.loads(base64.b64decode(code), fix_imports=False)
    do_modifications(d, '%s', %s, %s)
}

ROOTFS_POSTPROCESS_COMMAND += "system_update_test_modify;"

%s
%s
''' % (base64.b64encode(pickle.dumps(self.IMAGE_MODIFY._do_modifications, fix_imports=False)),
       testname,
       updates,
       is_update,
       self.IMAGE_CONFIG,
       self.IMAGE_MODIFY.modify_image_build(testname, updates, is_update)))

        # Creating a .bbappend for the image will trigger a rebuild.
        self.write_config('BBFILES_append = " %s"' % os.path.abspath(self.IMAGE_BBAPPEND))
        create_image_bbappend(False)
        self.logger.info('Building base image')
        result = bitbake(self.IMAGE_PN)
        self.logger.info('bitbake output: %s' % result.output)

        # Copying the entire deploy directory via hardlinks is relatively cheap
        # and gives us everything required to run qemu.
        self.image_dir = get_bb_var('DEPLOY_DIR_IMAGE')
        self.image_dir_test = self.image_dir + '.test'
        # self.track_for_cleanup(self.image_dir_test)
        oe.path.copyhardlinktree(self.image_dir, self.image_dir_test)

        # Now we change our .bbappend so that the updated state is generated
        # during the next rebuild.
        create_image_bbappend(True)
        self.logger.info('Building updated image')
        bitbake(self.IMAGE_PN)

        # Change DEPLOY_DIR_IMAGE so that we use our copy of the
        # images from before the update. Further customizations for booting can
        # be done by rewriting self.image_dir_test/IMAGE_PN-MACHINE.qemuboot.conf
        # (read, close, write, not just appending as that would also change
        # the file copy under image_dir).
        overrides = { 'DEPLOY_DIR_IMAGE': self.image_dir_test }

        # Boot image, verify before and after update.
        with self.boot_image(overrides) as qemu:
            self.verify_image(testname, False, qemu, updates)
            reboot = self.update_image(qemu)
            if not reboot:
                self.verify_image(testname, True, qemu, updates)
        if reboot:
            with self.boot_image(overrides) as qemu:
                self.verify_image(testname, True, qemu, updates)
