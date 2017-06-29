from oeqa.selftest.systemupdate.systemupdatebase import SystemUpdateBase

from oeqa.utils.commands import runqemu, get_bb_var

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
    IMAGE_PN = 'refkit-image-common'
    IMAGE_BBAPPEND = 'refkit-image-common.bbappend'
    IMAGE_CONFIG = '''
IMAGE_FEATURES_append = " ostree"
'''

    # Address and port of OSTree HTTPD inside the virtual machine's
    # slirp network.
    OSTREE_SERVER = '10.0.2.100:8080'

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
                                     '%s-%s.qemuboot.conf' % (self.IMAGE_PN, get_bb_var('MACHINE')))
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
        ostree_repo = os.path.join(get_bb_var('DEPLOY_DIR'), 'ostree-repo')
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
            with open(self.ostree_netcat.name, 'w') as f:
                f.write('''#!/bin/sh
exec netcat 2>>/tmp/ostree.log localhost 9999
#exec socat 2>>/tmp/ostree.log -D -v -d -d -d -d STDIO TCP:localhost:%d
''' % port)

            cmd = '''ostree config set 'remote "updates".url' http://%s && refkit-ostree update''' % self.OSTREE_SERVER
            status, output = qemu.run_serial(cmd, timeout=600)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            self.logger.info('Successful (?) update:\n%s' % output)
            return True
        finally:
            os.chdir(old_cwd)
            if server:
                # server.shutdown() has been seen to hang when handling exceptions,
                # so it isn't getting called at the moment.
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
