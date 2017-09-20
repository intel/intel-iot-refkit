from oeqa.selftest.systemupdate.httpupdate import HTTPUpdate

import contextlib
import copy
import os
import re
import shutil
import tempfile

class RefkitSwupdUpdateBase(HTTPUpdate):
    """
    System update tests for refkit-image-common using swupd.
    """

    # We test the normal refkit-image-common with
    # swupd system update enabled.
    IMAGE_PN = 'refkit-image-update-swupd'
    IMAGE_PN_UPDATE = IMAGE_PN
    IMAGE_BBAPPEND = IMAGE_PN + '.bbappend'
    IMAGE_BBAPPEND_UPDATE = IMAGE_BBAPPEND
    IMAGE_BUNDLES = []

    def setUp(self):
        # IMAGE_BBAPPEND always refers to the base image, whereas IMAGE_PN might be a virtual image.
        # The swupd repo gets produced for the base image. See RefkitSwupdBundleTestAll.
        self.SWUPD_DIR = os.path.join(HTTPUpdate.BB_VARS['DEPLOY_DIR'], 'swupd', HTTPUpdate.BB_VARS['MACHINE'],
                                      self.IMAGE_BBAPPEND[:-len('.bbappend')])
        self.REPO_DIR = os.path.join(self.SWUPD_DIR, 'www')
        self.maxDiff = None
        super().setUp()

    IMAGE_MODIFY = copy.copy(HTTPUpdate.IMAGE_MODIFY)

    # swupd cannot preserve local changes in /etc.
    IMAGE_MODIFY.ETC_FILES = [x for x in IMAGE_MODIFY.ETC_FILES if x[1] != 'edit']

    # efi_combo_updater currently fails during testing, which breaks the kernel update
    # test. TODO: fix that instead of disabling that aspect of the test.
    #
    # Failure is (visible only when invoking manually):
    # $ efi_combo_updater
    # ROOT_BLOCK_DEVICE (null)
    # Partition prefix: "p"
    # sh: syntax error: unexpected "("
    # efi_combo_updater: /fast/build/refkit/intel-corei7-64/tmp-glibc/work/corei7-64-refkit-linux/efi-combo-trigger/1.0-r0/efi_combo_updater.c:99: main: Assertion `execute(&efi_partition_nr, EFI_PARTITION_NR_CMD, root_block_device, EFI_TYPE) == 0' failed.
    # Aborted (core dumped)
    IMAGE_MODIFY.UPDATES.remove('kernel')

    def modify_image_build(self, testname, updates, is_update):
        """
        We use fixed versions 10 and 20 for original and modified image
        and generate a delta between 10 and 20.
        """
        bbappend = [super().modify_image_build(testname, updates, is_update)]
        if is_update:
            bbappend.append('OS_VERSION = "20"')
            bbappend.append('SWUPD_DELTAPACK_VERSIONS = "10"')
        else:
            bbappend.append('OS_VERSION = "10"')
        return '\n'.join(bbappend)

    def list_tree(self, dir):
        """
        Returns list of all entries underneath dir (files, symlinks and directories),
        with the full path relative to the base directory. Directories have a trailing
        slash.
        """
        items = []
        for root, dirs, files in os.walk(dir):
            base = os.path.relpath(root, dir)
            if base == '.':
                base = ''
            items.extend([os.path.join(base, item) for item in files])
            items.extend([os.path.join(base, item) + '/' for item in dirs])
        items.sort()
        return items

    def list_manifest(self, version):
        """
        Extract the list of still existing items recorded in the manifest, i.e.
        deleted items are ignored. Same result as for list_tree() (no leading slash,
        trailing slash for directories).
        """
        items = []
        entry_re = re.compile('^(?P<type>\S+)\s+(?P<hash>[0-9a-f]+)\s+(?P<version>\d+)\s+(?P<path>.*)$')
        with open(os.path.join(self.REPO_DIR, str(version), 'Manifest.full')) as f:
            for line in f:
                m = entry_re.match(line)
                if m and m.group('type') != '.d..':
                    items.append(m.group('path').lstrip('/') +
                                 ('/' if m.group('type').startswith('D') else ''))
        items.sort()
        return items

    def clean_swupd_repo(self):
        """
        Automatically clean the swupd repo when doing the normal testing
        with a single image recipe. RefkitSwupdUpdateTestDev avoids
        rebuilding but might fail because it does not always start from
        scratch.
        """
        if self.IMAGE_PN == self.IMAGE_PN_UPDATE and \
           os.path.exists(self.SWUPD_DIR):
            shutil.rmtree(self.SWUPD_DIR)

    def do_update(self, testname, updates, have_zero_packs=[], full_repo=True):
        self.clean_swupd_repo()

        # No need to reboot, unless the kernel was updated.
        # Refkit itself does not detect the need to reboot, so we have to decide
        # based on the test.
        self.update_needs_reboot = 'kernel' in updates

        super().do_update(testname, updates)

        # Here we can do some additional sanity checking of the content
        # of the swupd repo. Test-specific checks can be in the individual
        # test_* methods.
        repo_items = self.list_tree(self.REPO_DIR)
        expected = """10/
10/Manifest.MoM
10/Manifest.MoM.tar
10/Manifest.full
10/Manifest.full.tar
10/Manifest.os-core
10/Manifest.os-core.tar
20/
20/Manifest-os-core-delta-from-10
20/Manifest.MoM
20/Manifest.MoM.tar
20/Manifest.full
20/Manifest.full.tar
20/Manifest.os-core
20/Manifest.os-core.tar
20/format
20/pack-os-core-from-10.tar
20/swupd-server-src-version""".split('\n')
        for version in ('10', '20'):
            # Normal bundles always get packed to support installing them.
            for bundle in self.IMAGE_BUNDLES:
                expected.append('%s/pack-%s-from-0.tar' % (version, bundle))
            # os-core however is optional.
            if have_zero_packs is True or version in have_zero_packs:
                expected.append('%s/pack-os-core-from-0.tar' % version)
        for bundle in self.IMAGE_BUNDLES:
            # The bundles are not expected to change, therefore the
            # Manifests from build 10 are reused by build 20.
            for suffix in ('', '.tar'):
                expected.append('10/Manifest.%s%s' % (bundle, suffix))
            expected.append('20/pack-%s-from-10.tar' % bundle)
        if self.IMAGE_BUNDLES:
            # Apparently it only gets created if enough changes, which happens
            # to be when we have bundles.
            expected.append('20/Manifest-MoM-delta-from-10')
        if full_repo:
            expected.extend(['10/format', '10/swupd-server-src-version'])
        expected.sort()
        # Hidden files get excluded because of https://github.com/clearlinux/swupd-server/issues/99.
        self.assertEqual(expected,
                         [x for x in repo_items if \
                          '/.' not in x  and
                          '/delta/' not in x and
                          '/files/' not in x and
                          not x.startswith('version/')])

    def update_image_via_http(self, qemu):
        url = 'http://%s' % self.HTTPD_SERVER
        cmd = 'swupd update -c {0} -v {0}'.format(url)
        status, output = qemu.run_serial(cmd, timeout=600)
        self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        self.logger.info('Successful (?) update with %s:\n%s' % (cmd, output))
        # TODO: verify that the delta pack was downloaded
        return self.update_needs_reboot

    def update_image(self, qemu):
        # Dump some information about changes in version 20.
        lines = []
        lines.append('Changes in 20/Manifest.full:\n')
        entry_re = re.compile('^(?P<type>\S+)\s+(?P<hash>[0-9a-f]+)\s+(?P<version>\d+)\s+(?P<path>.*)$')
        with open(os.path.join(self.REPO_DIR, '20', 'Manifest.full')) as f:
            for line in f:
                m = entry_re.match(line)
                if m and m.group('version') == '20':
                    lines.append(line)
        self.logger.info(''.join(lines))
        super().update_image(qemu)

class RefkitSwupdUpdateTestAll(RefkitSwupdUpdateBase):
    def test_update_all(self):
        """
        Test all possible changes at once.
        """
        self.do_update('test_update_all', self.IMAGE_MODIFY.UPDATES)

        repo_items = self.list_tree(self.REPO_DIR)
        # 11 modified or new files, two directories.
        files = [x for x in repo_items if x.startswith('20/files/')]
        expected = 13
        if len(files) != expected:
            prefix_len = len('20/files/')
            hashes = []
            for item in repo_items:
                m = re.match(r'20/files/(.*).tar', item)
                if m:
                    hashes.append(m.group(1))
            file_names = []
            with open(os.path.join(self.REPO_DIR, '20', 'Manifest.full')) as f:
                for line in f:
                    if any(map(lambda x: x in line, hashes)):
                        file_names.append(line)
            self.fail('should have %d files, got %d:\n%s\n\nManifest.full:\n%s' % (expected, len(files), '\n'.join(files), ' '.join(file_names)))
        deltas = [x for x in repo_items if x.startswith('20/delta/') and x != '20/delta/']
        self.assertEqual(len(deltas), 1, msg='should have 1 delta for modify_files_large, got: %s' % deltas)


class RefkitSwupdBundleTestAll(RefkitSwupdUpdateTestAll):
    """
    This class inherits test_update_all, but applies it to a different set of images
    where bundles are enabled. The actual image that we test with has the "dev" bundle
    pre-installed.
    """

    IMAGE_PN = 'refkit-image-update-swupd-bundles-dev'
    IMAGE_PN_UPDATE = IMAGE_PN
    IMAGE_BBAPPEND = 'refkit-image-update-swupd-bundles.bbappend'
    IMAGE_BBAPPEND_UPDATE = IMAGE_BBAPPEND
    IMAGE_BUNDLES = ['feature_one', 'feature_two']


class RefkitSwupdUpdateTestIncremental(RefkitSwupdUpdateBase):

    def modify_image_build(self, testname, updates, is_update):
        """
        Preserve only www directory before the second build.
        """
        bbappend = [super().modify_image_build(testname, updates, is_update)]

        if is_update:
            # Move the www directory into a different location, then
            # delete the swupd directory. The old content gets used
            # via file:// URLs.
            if os.path.exists(self.wwwdir):
                shutil.rmtree(self.wwwdir)
            os.rename(self.REPO_DIR, self.wwwdir)
            shutil.rmtree(self.SWUPD_DIR)
            bbappend.append('SWUPD_VERSION_BUILD_URL = "file:///%s"' % self.wwwdir)
            bbappend.append('SWUPD_CONTENT_BUILD_URL = "file:///%s"' % self.wwwdir)
            # Also do a delta pack.
            bbappend.append('SWUPD_DELTAPACK_VERSIONS = "10"')
            # Stage all files, to ensure that this works also for directories.
            bbappend.append('SWUPD_GENERATE_OS_CORE_ZERO_PACK = "true"')

        return '\n'.join(bbappend)

    def setUp(self):
        self.wwwdir = os.path.abspath('test-swupd-www')
        # self.track_for_cleanup(self.wwwdir)
        super().setUp()

    def test_update_incremental(self):
        """
        Simulates the default workflow where each build starts with empty TMPDIR
        and previous swupd repo data must be retrieved via the content and version
        build URLs. Enables delta packs, too.
        """
        self.do_update('test_update_incremental', self.IMAGE_MODIFY.UPDATES,
                       full_repo=False,
                       have_zero_packs=['20'])

class RefkitSwupdUpdateMeta(type):
    """
    Generates individual instances of test_update_<update>, one for each type of change.
    """
    def __new__(mcs, name, bases, dict):
        def add_test(update):
            test_name = 'test_update_' + update
            def test(self):
                self.do_update(test_name, [update])
            dict[test_name] = test
        for update in RefkitSwupdUpdateBase.IMAGE_MODIFY.UPDATES:
            add_test(update)
        return type.__new__(mcs, name, bases, dict)

class RefkitSwupdUpdateTestIndividual(RefkitSwupdUpdateBase, metaclass=RefkitSwupdUpdateMeta):
    pass

class RefkitSwupdUpdateTestDev(RefkitSwupdUpdateTestAll, metaclass=RefkitSwupdUpdateMeta):
    """
    This class avoids rootfs rebuilding by using two separate image
    recipes. The other tests are more realistic. Use this one when debugging problems,
    and beware that the swupd repo must be removed manually (if necessary).
    """

    IMAGE_PN_UPDATE = 'refkit-image-update-swupd-modified'
    IMAGE_BBAPPEND_UPDATE = IMAGE_PN_UPDATE + '.bbappend'

class RefkitSwupdPartitionTest(RefkitSwupdUpdateBase):
    """
    Builds two OS releases and then exercises various code paths
    in swupd-update-partition.
    """

    # Run tests with "REFKIT_SWUPD_REUSE_REPO=1 oe-selftest -r refkit_swupd.RefkitSwupdPartitionTest"
    # to avoid rebuilding. Beware that the repo must be cleaned manually when making content
    # changes in that case.
    if 'REFKIT_SWUPD_REUSE_REPO' in os.environ:
        IMAGE_PN_UPDATE = 'refkit-image-update-swupd-modified'
        IMAGE_BBAPPEND_UPDATE = IMAGE_PN_UPDATE + '.bbappend'

    # Derived from INT_STORAGE_ROOTFS_PARTUUID_VALUE by reversing the digits in the first value.
    # We just need something that is unique.
    PARTUUID = "87654321-9abc-def0-0fed-cba987654320"

    def modify_image_build(self, testname, updates, is_update):
        bbappend = [super().modify_image_build(testname, updates, is_update)]
        # A/B partitioning scheme where the system partition is read-only.
        bbappend.append('REFKIT_EXTRA_PARTITION = "part ${REFKIT_IMAGE_SIZE} --fstype=ext4 --label inactive --align 1024 --uuid %s"' % self.PARTUUID)
        bbappend.append('REFKIT_IMAGE_EXTRA_FEATURES_append = " read-only-rootfs"')
        # Needed for installing from scratch.
        bbappend.append('SWUPD_GENERATE_OS_CORE_ZERO_PACK = "true"')
        # Needed for formatting the partition.
        bbappend.append('REFKIT_IMAGE_EXTRA_INSTALL_append = " e2fsprogs"')
        return '\n'.join(bbappend)

    def normalize_partition_output(self, output, unknown_missing=False):
        # Strip CR.
        output = output.replace('\r', '')
        # Replace random mktemp names.
        output, _ = re.subn(r'/swupd-(version|mount|mount-source)\..{6}', r'/swupd-\1.X', output)
        # mkfs output is irrelevant and varies (version number, block numbers, etc.)
        output, _ = re.subn(r'(^swupd-update-partition: (?:sh -c .)?mkfs[^\n]*\n).*?Writing superblocks and filesystem accounting information: [^\n]*done\n',
                            r'\1...',
                            output,
                            flags=re.MULTILINE|re.DOTALL)
        # Replace or even remove (when on their own line) progress percentages.
        output, _ = re.subn(r'(\.\.\.\d+%\s*)+', '...100%\n', output)
        output, _ = re.subn(r'^\s*...100%\s*\n', '', output, flags=re.MULTILINE)
        # We don't care about the swupd version and copyright.
        output, _ = re.subn(r'^swupd-client software.*\n   Copyright.*\n', 'swupd-client software ...\n', output, flags=re.MULTILINE)
        # Number of files may vary.
        output, _ = re.subn(r'Inspected \d+ files', 'Inspected xxx files', output)
        # Timing varies.
        output, _ = re.subn(r'Update took \d+.\d seconds', 'Update took x.y seconds', output)
        # Re-installing from scratch means we don't know how many files actually miss (depends on OS).
        if unknown_missing:
            output, _ = re.subn(r'\d+ files were missing', 'xxx files were missing', output)
            output, _ = re.subn(r'\d+ of \d+ missing files were replaced', 'xxx of xxx missing files were replaced', output)
            output, _ = re.subn(r'0 of \d+ missing files were not replaced', '0 of xxx missing files were not replaced', output)
        return output

    def update_partition(self, cmd, expected, version, network_error=None, **kwargs):
        """
        Run a single swupd-update-partition command and check the result, including the HTTP log.
        """
        self.httpd.http_log.clear()
        self.httpd.stop_at = network_error
        self.logger.info(cmd)
        status, output = self.qemu.run_serial(cmd, timeout=600)
        self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        self.logger.info(output)
        output = self.normalize_partition_output(output, **kwargs)
        # Normalize the HTTP log by replacing /10/files/57de850a026aee38bb06a2a8d6c014a773c2dc3268032b44c0b5b3e7e4ec53f2.tar
        # with
        log = []
        manifest = {}
        def hash2file(hash):
            if not manifest:
                # L...    7392ad572c8a806372e327a1908e69266f319da796284e9758ddadd888bbf1d4        10      /bin
                entry_re = re.compile('^(?P<type>\S+)\s+(?P<hash>[0-9a-f]+)\s+(?P<version>\d+)\s+(?P<path>.*)$')
                with open(os.path.join(self.REPO_DIR, str(version), 'Manifest.full')) as f:
                    for line in f:
                        m = entry_re.match(line)
                        if m:
                            # Use the first path associated with a hash. There might be more than one.
                            manifest.setdefault(m.group('hash'), m.group('path'))
            return manifest.get(hash, hash)
        file_re = re.compile(r'/(?P<version>\d+)/files/(?P<hash>[0-9a-f]+).tar')
        for request in self.httpd.http_log:
            request = file_re.sub(lambda m: '/%s/files/<%s>.tar' % (m.group('version'), hash2file(m.group('hash'))),
                                  request)
            log.append(request)
        output += '\n\n' + '\n'.join(log) + '\n'
        self.assertEqual(expected, output)

        # Verify partition content.
        cmd = 'mountpoint=`mktemp -d` && ' + \
              'mount -oro /dev/disk/by-partuuid/{0} $mountpoint && '.format(self.PARTUUID) + \
              '''find $mountpoint -mindepth 1 | while read item; do [ -d "$item" ] && ! [ -L "$item" ] && echo "$item/" || echo "$item"; done | sed -e "s;^$mountpoint/;;"' && ''' + \
              'umount $mountpoint'
        # TODO: actually enable the code - currently it fails because extra items
        # under /etc and /var are not getting removed by swupd (https://github.com/clearlinux/swupd-client/issues/293)
        #status, output = self.qemu.run_serial(cmd, timeout=600)
        #self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        #expected = self.list_manifest(version)
        #self.assertEqual(expected, sorted(map(str.strip, output.split('\n'))))


    def verify_image(self, testname, is_update, qemu, updates):
        # Nothing to verify.
        pass

    @classmethod
    def setUpClass(cls):
        """
        Build update stream and boot image only once for all tests
        by tracking whether we have done the work already and
        cleaning up if we have.
        """
        cls.qemu = None
        cls.exit_stack = contextlib.ExitStack()
        super().setUpClass()

    def setUp(self):
        super().setUp()
        self.url = 'http://%s' % self.HTTPD_SERVER
        testname = 'RefkitSwupdPartitionTest'
        updates = self.IMAGE_MODIFY.UPDATES
        if RefkitSwupdPartitionTest.qemu is None:
            self.logger.info('Preparing testing with the following modifications: ' + ' '.join(updates))
            self.clean_swupd_repo()
            self.prepare_image(testname, updates)
            RefkitSwupdPartitionTest.qemu = self.exit_stack.enter_context(self.boot_and_verify_image(testname, updates))
            self.prepare_update(testname, updates)
            RefkitSwupdPartitionTest.httpd = self.exit_stack.enter_context(self.start_httpd())

    @classmethod
    def tearDownClass(cls):
        RefkitSwupdPartitionTest.qemu = None
        cls.exit_stack.close()

    def test_update_without_source(self):
        """
        Install and update without source.
        """

        # Install after force formatting.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 10 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -F'.format(self.url, self.PARTUUID)
        expected = '''swupd-update-partition: Updating to 10 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: mkfs.ext4 -F /dev/disk/by-partuuid/{uuid}
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Installing into empty partition.
swupd-update-partition: swupd verify --install --no-scripts -F 4 -c {url} -v file:///tmp/swupd-version.X -m 10 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 10
Downloading packs...

Extracting os-core pack for version 10
Adding any missing files
Inspected xxx files
  xxx files were missing
    xxx of xxx missing files were replaced
    0 of xxx missing files were not replaced
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
"GET /10/pack-os-core-from-0.tar HTTP/1.1" 200 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 10, unknown_missing=True)

        # Incremental update.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}"'.format(self.url, self.PARTUUID)
        expected = '''swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Trying to update.
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20
Running script 'Pre-update'
Downloading packs...

Extracting os-core pack for version 20
Statistics for going from version 10 to version 20:

    changed bundles   : 1
    new bundles       : 0
    deleted bundles   : 0

    changed files     : 11
    new files         : 3
    deleted files     : 1

Starting download of remaining update content. This may take a while...
Finishing download of update content...
Staging file content
Applying update
Update was applied.
WARNING: post-update helper scripts skipped due to --no-scripts argument
Update took x.y seconds
Update successful. System updated from version 10 to version 20
swupd-update-partition: Verifying and fixing content.
swupd-update-partition: swupd verify --fix --picky --picky-tree / --picky-whitelist ^/swupd-state/ --no-scripts -F 4 -c {url} -v file:///tmp/swupd-version.X -m 20 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 20
Starting download of remaining update content. This may take a while...
Finishing download of update content...
Adding any missing files

Fixing modified files
--picky removing extra files under /tmp/swupd-mount.X/
Inspected xxx files
  0 files were missing
  0 files found which should be deleted
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /20/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
"GET /20/Manifest-os-core-delta-from-10 HTTP/1.1" 200 -
"GET /20/pack-os-core-from-10.tar HTTP/1.1" 200 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 10)


    def test_update_with_source(self):
        """
        Install and update with source partition.
        """

        # Install after force formatting, with source partition.
        # Source and target have the same version.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 10 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -F -s /'.format(self.url, self.PARTUUID)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 10 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: mkfs.ext4 -F /dev/disk/by-partuuid/{uuid}
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c http://10.0.2.100:8080 -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Version on server (10) is not newer than system version (10)
Update complete. System already up-to-date at version 10
swupd-update-partition: Verifying and fixing content.
swupd-update-partition: swupd verify --fix --picky --picky-tree / --picky-whitelist ^/swupd-state/ --no-scripts -F 4 -c {url} -v file:///tmp/swupd-version.X -m 10 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 10
Starting download of remaining update content. This may take a while...
Finishing download of update content...
Adding any missing files

Fixing modified files
--picky removing extra files under /tmp/swupd-mount.X/
Inspected xxx files
  0 files were missing
  0 files found which should be deleted
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 10)

        # Update, with source, without formatting.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -s /'.format(self.url, self.PARTUUID)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Trying to update.
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20
Running script 'Pre-update'
Downloading packs...

Extracting os-core pack for version 20
Statistics for going from version 10 to version 20:

    changed bundles   : 1
    new bundles       : 0
    deleted bundles   : 0

    changed files     : 11
    new files         : 3
    deleted files     : 1

Starting download of remaining update content. This may take a while...
Finishing download of update content...
Staging file content
Applying update
Update was applied.
WARNING: post-update helper scripts skipped due to --no-scripts argument
Update took x.y seconds
Update successful. System updated from version 10 to version 20
swupd-update-partition: Verifying and fixing content.
swupd-update-partition: swupd verify --fix --picky --picky-tree / --picky-whitelist ^/swupd-state/ --no-scripts -F 4 -c http://10.0.2.100:8080 -v file:///tmp/swupd-version.X -m 20 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 20
Starting download of remaining update content. This may take a while...
Finishing download of update content...
Adding any missing files

Fixing modified files
--picky removing extra files under /tmp/swupd-mount.X/
Inspected xxx files
  0 files were missing
  0 files found which should be deleted
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /20/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
"GET /20/Manifest-os-core-delta-from-10 HTTP/1.1" 200 -
"GET /20/pack-os-core-from-10.tar HTTP/1.1" 200 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 20)


    def test_update(self):
        """
        Update, with formatting.
        """

        # Update, with source, with formatting.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -F -s /; ret=$?; [ $ret -eq 0 ]'.format(self.url, self.PARTUUID)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: mkfs.ext4 -F /dev/disk/by-partuuid/87654321-9abc-def0-0fed-cba987654320
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20
Running script 'Pre-update'
Downloading packs...

Extracting os-core pack for version 20
Statistics for going from version 10 to version 20:

    changed bundles   : 1
    new bundles       : 0
    deleted bundles   : 0

    changed files     : 11
    new files         : 3
    deleted files     : 1

Starting download of remaining update content. This may take a while...
Finishing download of update content...
Staging file content
Applying update
Update was applied.
WARNING: post-update helper scripts skipped due to --no-scripts argument
Update took x.y seconds
Update successful. System updated from version 10 to version 20
swupd-update-partition: Verifying and fixing content.
swupd-update-partition: swupd verify --fix --picky --picky-tree / --picky-whitelist ^/swupd-state/ --no-scripts -F 4 -c http://10.0.2.100:8080 -v file:///tmp/swupd-version.X -m 20 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 20
Starting download of remaining update content. This may take a while...
Finishing download of update content...
Adding any missing files

Fixing modified files
--picky removing extra files under /tmp/swupd-mount.X/
Inspected xxx files
  0 files were missing
  0 files found which should be deleted
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /20/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
"GET /20/Manifest-os-core-delta-from-10 HTTP/1.1" 200 -
"GET /20/pack-os-core-from-10.tar HTTP/1.1" 200 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 20)


    def test_extra_files(self):
        """
        Update, with formatting, then remove extra files.
        """

        # Update, with source, with formatting. Our source partition
        # is read-only, so in order to place extra files into the
        # target partition we use a trick: we add additional commands
        # to the format command that swupd-update-partition invokes.
        mkfscmd = "sh -c 'mkfs.ext4 -F /dev/disk/by-partuuid/{0} && " \
              "mkdir /tmp/extra-files && " \
              "mount /dev/disk/by-partuuid/{0} /tmp/extra-files && " \
              "mkdir /tmp/extra-files/remove && " \
              "touch /tmp/extra-files/remove/me && " \
              "mkdir -p /tmp/extra-files/usr/local && " \
              "touch /tmp/extra-files/usr/local/remove-me && " \
              "chmod -R a-r /tmp/extra-files/remove /tmp/extra-files/usr/local && " \
              "umount /tmp/extra-files && rmdir /tmp/extra-files'".format(self.PARTUUID)
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "{2}" -F -s /; ret=$?; [ $ret -eq 0 ]'.format(self.url, self.PARTUUID, mkfscmd)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: {mkfscmd}
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20
Running script 'Pre-update'
Downloading packs...

Extracting os-core pack for version 20
Statistics for going from version 10 to version 20:

    changed bundles   : 1
    new bundles       : 0
    deleted bundles   : 0

    changed files     : 11
    new files         : 3
    deleted files     : 1

Starting download of remaining update content. This may take a while...
Finishing download of update content...
Staging file content
Applying update
Update was applied.
WARNING: post-update helper scripts skipped due to --no-scripts argument
Update took x.y seconds
Update successful. System updated from version 10 to version 20
swupd-update-partition: Verifying and fixing content.
swupd-update-partition: swupd verify --fix --picky --picky-tree / --picky-whitelist /swupd-state --no-scripts -F 4 -c http://10.0.2.100:8080 -v file:///tmp/swupd-version.X -m 20 -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Verifying version 20
Starting download of remaining update content. This may take a while...
Finishing download of update content...
Adding any missing files

Fixing modified files
--picky removing extra files under /tmp/swupd-mount.X/
REMOVING /usr/local/remove-me
REMOVING DIR /usr/local/
REMOVING /remove/me
REMOVING DIR /remove/
Inspected xxx files
  0 files were missing
  0 files found which should be deleted
WARNING: post-update helper scripts skipped due to --no-scripts argument
Fix successful
swupd-update-partition: umount /tmp/swupd-mount.X
swupd-update-partition: Update successful.

"GET /10/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /20/Manifest.MoM.tar HTTP/1.1" 200 -
"GET /10/Manifest.os-core.tar HTTP/1.1" 200 -
"GET /20/Manifest-os-core-delta-from-10 HTTP/1.1" 200 -
"GET /20/pack-os-core-from-10.tar HTTP/1.1" 200 -
'''.format(
    mkfscmd=mkfscmd,
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 20)


    def test_update_network_0(self):
        """
        Same as test_update, but with network errors before first HTTP request.
        """

        # Update, with source, with formatting.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -F -s /; ret=$?; [ $ret -eq 2 ]'.format(self.url, self.PARTUUID)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: mkfs.ext4 -F /dev/disk/by-partuuid/87654321-9abc-def0-0fed-cba987654320
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20
Failed to retrieve 10 MoM manifest
Retry #1 downloading from/to MoM Manifests
Failed to retrieve 10 MoM manifest
Retry #2 downloading from/to MoM Manifests
Failed to retrieve 10 MoM manifest
Retry #3 downloading from/to MoM Manifests
Failed to retrieve 10 MoM manifest
Failure retrieving manifest from server
Update took x.y seconds
swupd-update-partition: swupd: EMOM_NOTFOUND = 4 = MoM cannot be loaded into memory (this could imply network issue)
swupd-update-partition: Update failed temporarily.

code 500, message test server is intentionally down
"GET /10/Manifest.MoM.tar HTTP/1.1" 500 -
code 500, message test server is intentionally down
"GET /10/Manifest.MoM.tar HTTP/1.1" 500 -
code 500, message test server is intentionally down
"GET /10/Manifest.MoM.tar HTTP/1.1" 500 -
code 500, message test server is intentionally down
"GET /10/Manifest.MoM.tar HTTP/1.1" 500 -
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 20, network_error=0)


    def test_update_network_4(self):
        """
        Same as test_update, but with network errors before fifth HTTP request.
        """

        self.skipTest('swupd does not detect this network error as it should - https://github.com/clearlinux/swupd-client/issues/323')

        # Update, with source, with formatting.
        cmd = 'swupd-update-partition -c {0} -p /dev/disk/by-partuuid/{1} -m 20 -f "mkfs.ext4 -F /dev/disk/by-partuuid/{1}" -F -s /; ret=$?; [ $ret -eq 2 ]'.format(self.url, self.PARTUUID)
        # Some /etc files get modified at runtime due to the writable
        # rootfs and thus do not match.
        expected = '''swupd-update-partition: Bind-mounting source tree.
swupd-update-partition: mount -obind,ro / /tmp/swupd-mount-source.X
swupd-update-partition: Updating to 20 from {url}.
swupd-update-partition: Reinstalling from scratch.
swupd-update-partition: Formatting partition.
swupd-update-partition: mkfs.ext4 -F /dev/disk/by-partuuid/87654321-9abc-def0-0fed-cba987654320
...
swupd-update-partition: mount /dev/disk/by-partuuid/{uuid} /tmp/swupd-mount.X
swupd-update-partition: rm -rf /tmp/swupd-mount.X/lost+found
swupd-update-partition: Copy from source /.
swupd-update-partition: Trying to update.
swupd-update-partition: swupd update --no-scripts -c {url} -v file:///tmp/swupd-version.X -S /tmp/swupd-mount.X/swupd-state -p /tmp/swupd-mount.X
swupd-client software ...

Update started.
Attempting to download version string to memory
Preparing to update from 10 to 20

TODO: insert actual output.
'''.format(
    uuid=self.PARTUUID,
    url=self.url
)
        self.update_partition(cmd, expected, 20, network_error=4)
