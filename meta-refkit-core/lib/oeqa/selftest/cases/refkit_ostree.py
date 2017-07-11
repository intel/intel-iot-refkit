from oeqa.selftest.systemupdate.systemupdatebase import SystemUpdateBase

from oeqa.utils.commands import runqemu, get_bb_vars, bitbake

import errno
import http.server
import os
import stat
import tempfile
import threading

class RefkitOSTreeUpdateBase(SystemUpdateBase):
    """
    System update tests for refkit-image-common using OSTree.
    """

    # We test the normal refkit-image-common with
    # OSTree system update enabled.
    IMAGE_PN = 'refkit-image-update-ostree'
    IMAGE_PN_UPDATE = IMAGE_PN
    IMAGE_BBAPPEND = IMAGE_PN + '.bbappend'
    IMAGE_BBAPPEND_UPDATE = IMAGE_BBAPPEND

    # Address and port of OSTree HTTPD inside the virtual machine's
    # slirp network.
    OSTREE_SERVER = '10.0.2.100:8080'

    # Global variables are the same for all recipes,
    # but RECIPE_SYSROOT_NATIVE is specific to socat-native.
    BB_VARS = get_bb_vars([
        'DEPLOY_DIR',
        'MACHINE',
        'RECIPE_SYSROOT_NATIVE',
        ],
                          'socat-native')

    def track_for_cleanup(self, name):
        """
        Run a single test with NO_CLEANUP=<anything> oe-selftest to not clean up after the test.
        """
        if 'NO_CLEANUP' not in os.environ:
            super().track_for_cleanup(name)

    def boot_image(self, overrides):
        # We don't know the final port yet, so instead we create a placeholder script
        # for qemu to use and rewrite that script once we are ready. The kernel refuses
        # to execute a shell script while we have it open, so here we close it
        # and clean up ourselves.
        #
        # The helper script also keeps command line handling a bit simpler (no whitespace
        # in -netdev parameter), which may or may not be relevant.
        self.ostree_netcat = tempfile.NamedTemporaryFile(mode='w', prefix='ostree-netcat-', dir=os.getcwd(), delete=False)
        self.ostree_netcat.close()
        os.chmod(self.ostree_netcat.name, stat.S_IRUSR|stat.S_IWUSR|stat.S_IXUSR)
        self.track_for_cleanup(self.ostree_netcat.name)

        qemuboot_conf = os.path.join(self.image_dir_test,
                                     '%s-%s.qemuboot.conf' % (self.IMAGE_PN, self.BB_VARS['MACHINE']))
        with open(qemuboot_conf) as f:
            conf = f.read()
        with open(qemuboot_conf, 'w') as f:
            f.write('\n'.join([x for x in conf.splitlines() if not x.startswith('qb_slirp_opt')]))
            f.write('\nqb_slirp_opt = -netdev user,id=net0,guestfwd=tcp:%s-cmd:%s\n' % \
                    (self.OSTREE_SERVER, self.ostree_netcat.name))
        return runqemu(self.IMAGE_PN,
                       discard_writes=False, ssh=False,
                       overrides=overrides,
                       runqemuparams='ovmf slirp nographic',
                       image_fstype='wic')

    def update_image(self, qemu):
        # We need to bring up some simple HTTP server for the
        # OSTree repo. We cannot get the actual OSTREE_REPO for the
        # image here, so we just assume that it is in the usual place.
        # For the sake of simplicity we change into that directory
        # because then we can use SimpleHTTPRequestHandler.
        ostree_repo = os.path.join(self.BB_VARS['DEPLOY_DIR'], 'ostree-repo')
        old_cwd = os.getcwd()
        server = None
        try:
            os.chdir(ostree_repo)
            class OSTreeHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
                def log_message(s, format, *args):
                    msg = format % args
                    self.logger.info(msg)

            handler = OSTreeHTTPRequestHandler

            def create_httpd():
                for port in range(9999, 10000):
                    try:
                        server = http.server.HTTPServer(('localhost', port), handler)
                        return server
                    except OSError as ex:
                        if ex.errno != errno.EADDRINUSE:
                            raise
                self.fail('no port available for OSTree HTTP server')

            server = create_httpd()
            port = server.server_port
            self.logger.info('serving OSTree repo %s on port %d' % (ostree_repo, port))
            helper = threading.Thread(name='OSTree HTTPD', target=server.serve_forever)
            helper.start()
            # netcat can't be assumed to be present. Build and use socat instead.
            # It's a bit more complicated but has the advantage that it is in OE-core.
            socat = os.path.join(self.BB_VARS['RECIPE_SYSROOT_NATIVE'], 'usr', 'bin', 'socat')
            if not os.path.exists(socat):
                bitbake('socat-native:do_addto_recipe_sysroot', output_log=self.logger)
            self.assertExists(socat, 'socat-native was not built as expected')
            with open(self.ostree_netcat.name, 'w') as f:
                f.write('''#!/bin/sh
exec %s 2>>/tmp/ostree.log -D -v -d -d -d -d STDIO TCP:localhost:%d
''' % (socat, port))

            cmd = '''ostree config set 'remote "updates".url' http://%s && refkit-ostree update''' % self.OSTREE_SERVER
            status, output = qemu.run_serial(cmd, timeout=600)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            self.logger.info('Successful (?) update:\n%s' % output)
            return True
        finally:
            os.chdir(old_cwd)
            if server:
                server.shutdown()
                server.server_close()

class RefkitOSTreeUpdateTestAll(RefkitOSTreeUpdateBase):
    def test_update_all(self):
        """
        Test all possible changes at once.
        """
        self.do_update('test_update_all', self.IMAGE_MODIFY.UPDATES)

class RefkitOSTreeUpdateMeta(type):
    """
    Generates individual instances of test_update_<update>, one for each type of change.
    """
    def __new__(mcs, name, bases, dict):
        def add_test(update):
            test_name = 'test_update_' + update
            def test(self):
                self.do_update(test_name, [update])
            dict[test_name] = test
        for update in RefkitOSTreeUpdateBase.IMAGE_MODIFY.UPDATES:
            add_test(update)
        return type.__new__(mcs, name, bases, dict)

class RefkitOSTreeUpdateTestIndividual(RefkitOSTreeUpdateBase, metaclass=RefkitOSTreeUpdateMeta):
    pass

class RefkitOSTreeUpdateTestDev(RefkitOSTreeUpdateTestAll, metaclass=RefkitOSTreeUpdateMeta):
    """
    This class avoids rootfs rebuilding by using two separate image
    recipes. It's using slight tricks like overriding the OSTREE_BRANCH,
    so the other tests are more realistic. Use this one when debugging problems.
    """

    IMAGE_PN_UPDATE = 'refkit-image-update-ostree-modified'
    IMAGE_BBAPPEND_UPDATE = IMAGE_PN_UPDATE + '.bbappend'

    def setUpLocal(self):
        super().setUpLocal()
        def create_image_bb(pn):
            bb = pn + '.bb'
            self.track_for_cleanup(bb)
            self.append_config('BBFILES_append = " %s"' % os.path.abspath(bb))
            with open(bb, 'w') as f:
                f.write('require ${META_REFKIT_CORE_BASE}/recipes-images/images/refkit-image-common.bb\n')
                f.write('OSTREE_BRANCHNAME = "${DISTRO}/${MACHINE}/%s"\n' % self.IMAGE_PN)
                f.write('''IMAGE_FEATURES_append = "${@ bb.utils.filter('DISTRO_FEATURES', 'stateless', d)}"\n''')
        create_image_bb(self.IMAGE_PN)
        create_image_bb(self.IMAGE_PN_UPDATE)
