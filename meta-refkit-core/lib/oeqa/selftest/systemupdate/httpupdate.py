from oeqa.selftest.systemupdate.systemupdatebase import SystemUpdateBase
from oeqa.utils.commands import runqemu, get_bb_vars, bitbake

import http.server
import os
import stat
import errno
import tempfile
import threading

class HTTPUpdate(SystemUpdateBase):
    """
    System update tests for image update mechanisms which depend on
    and HTTP server that provides files to the virtual machine.

    Uses SLIRP networking and thus can be used for images which
    rely on a DHCP server.
    """

    # Address and port of HTTPD inside the virtual machine's
    # slirp network.
    HTTPD_SERVER = '10.0.2.100:8080'

    # Global variables are the same for all recipes,
    # but RECIPE_SYSROOT_NATIVE is specific to socat-native.
    # We store that in the class because then it can be shared by
    # multiple derived instances.
    class DelayedGetVars:
        def __init__(self):
            self._cache = None

        def __getitem__(self, key):
            if self._cache is None:
                self._cache = get_bb_vars([
                    'DEPLOY_DIR',
                    'MACHINE',
                    'RECIPE_SYSROOT_NATIVE',
                    ],
                    'socat-native')
            return self._cache[key]

    BB_VARS = DelayedGetVars()

    # To be set by derived class or instance.
    REPO_DIR = None

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
        self.httpd_netcat = tempfile.NamedTemporaryFile(mode='w', prefix='httpd-netcat-', dir=os.getcwd(), delete=False)
        self.httpd_netcat.close()
        os.chmod(self.httpd_netcat.name, stat.S_IRUSR|stat.S_IWUSR|stat.S_IXUSR)
        self.track_for_cleanup(self.httpd_netcat.name)

        qemuboot_conf = os.path.join(self.image_dir_test,
                                     '%s-%s.qemuboot.conf' % (self.IMAGE_PN, self.BB_VARS['MACHINE']))
        with open(qemuboot_conf) as f:
            conf = f.read()
        with open(qemuboot_conf, 'w') as f:
            f.write('\n'.join([x for x in conf.splitlines() if not x.startswith('qb_slirp_opt')]))
            f.write('\nqb_slirp_opt = -netdev user,id=net0,guestfwd=tcp:%s-cmd:%s\n' % \
                    (self.HTTPD_SERVER, self.httpd_netcat.name))
        return runqemu(self.IMAGE_PN,
                       discard_writes=False, ssh=False,
                       overrides=overrides,
                       runqemuparams='ovmf slirp nographic',
                       image_fstype='wic')

    def update_image(self, qemu):
        # We need to bring up some simple HTTP server for the
        # update repo.
        server = None
        self.http_log = []
        http_log = self.http_log
        try:
            class HTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
                parent = self
                request_counter = 0
                def log_message(self, format, *args):
                    msg = format % args
                    self.parent.logger.info(msg)
                    self.parent.http_log.append(msg)

                def translate_path(self, path):
                    """
                    Return absolute path based on document root instead of current directory.
                    """

                    # The original implementation returns an absolute path rooted in the
                    # current directory. We need to serve a different
                    # directory without being able to chdir(), because
                    # doing that would cause commands like bitbake to
                    # run there, which is undesirable because for
                    # example bitbake creates a bitbake-cookerdaemon.log
                    # in the current directory.
                    path = super().translate_path(path)
                    relpath = os.path.relpath(path)
                    path = os.path.join(self.parent.REPO_DIR, relpath)
                    return path

                def do_GET(self):
                    """
                    Inject errors.
                    """
                    counter = HTTPRequestHandler.request_counter
                    HTTPRequestHandler.request_counter += 1
                    stop_at = getattr(self.parent, 'stop_serving_http_at', None)
                    if stop_at is not None and counter >= stop_at:
                        self.send_error(500, 'test server is intentionally down')
                    else:
                        super().do_GET()

            handler = HTTPRequestHandler

            def create_httpd():
                for port in range(9999, 10000):
                    try:
                        server = http.server.HTTPServer(('localhost', port), handler)
                        return server
                    except OSError as ex:
                        if ex.errno != errno.EADDRINUSE:
                            raise
                self.fail('no port available for HTTP server')

            server = create_httpd()
            port = server.server_port
            self.logger.info('serving repo %s on port %d' % (self.REPO_DIR, port))
            helper = threading.Thread(name='HTTPD', target=server.serve_forever)
            helper.start()
            # netcat can't be assumed to be present. Build and use socat instead.
            # It's a bit more complicated but has the advantage that it is in OE-core.
            socat = os.path.join(self.BB_VARS['RECIPE_SYSROOT_NATIVE'], 'usr', 'bin', 'socat')
            if not os.path.exists(socat):
                bitbake('socat-native:do_addto_recipe_sysroot', output_log=self.logger)
            self.assertExists(socat, 'socat-native was not built as expected')
            with open(self.httpd_netcat.name, 'w') as f:
                f.write('''#!/bin/sh
exec %s 2>/tmp/httpd.log -D -v -d -d -d -d STDIO TCP:localhost:%d
''' % (socat, port))

            # Now run the real update command inside the virtual machine.
            return self.update_image_via_http(qemu)

        finally:
            if server:
                server.shutdown()
                server.server_close()

    def update_image_via_http(self, qemu):
        """
        Called by update_image() with the HTTPD server running.
        """
        return False
