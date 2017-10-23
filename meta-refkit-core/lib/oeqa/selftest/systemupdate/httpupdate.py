from oeqa.selftest.systemupdate.systemupdatebase import SystemUpdateBase
from oeqa.utils.commands import runqemu, get_bb_vars, bitbake

import contextlib
import http.server
import os
import stat
import errno
import tempfile
import traceback
import threading

class HTTPServer(object):
    """
    Dynamically finds an available port and serves a certain directory there.
    To be used in a "with HTTPServer(dir) as httpd" construct.
    """
    def __init__(self, root, logger):
        self.root = root
        self.logger = logger
        self.server = None
        self.http_log = []
        self.stop_at = None

    def __enter__(self):
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
                    path = os.path.join(self.parent.root, relpath)
                    return path

                def do_GET(self):
                    """
                    Inject errors.
                    """
                    counter = HTTPRequestHandler.request_counter
                    HTTPRequestHandler.request_counter += 1
                    if self.parent.stop_at is not None and counter >= self.parent.stop_at:
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

            self.server = create_httpd()
            self.port = self.server.server_port
            self.logger.info('serving repo %s on port %d' % (self.root, self.port))
            helper = threading.Thread(name='HTTPD', target=self.server.serve_forever)
            helper.start()

            # Now let caller do its work while the server runs.
            return self
        except:
            self._stop()
            raise

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._stop()

    def _stop(self):
        # We have to stop a running server under all circumstances,
        # otherwise the helper thread will keep running and we end up
        # with thread locking issues.
        if self.server:
            self.server.shutdown()
            self.server.server_close()
            self.server = None

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

    @contextlib.contextmanager
    def boot_image(self, overrides = {}):
        # We don't know the final port yet, so instead we create a placeholder script
        # for qemu to use and rewrite that script once we are ready. The kernel refuses
        # to execute a shell script while we have it open, so here we close it
        # and clean up ourselves.
        #
        # The helper script also keeps command line handling a bit simpler (no whitespace
        # in -netdev parameter), which may or may not be relevant.
        self.httpd_netcat = tempfile.NamedTemporaryFile(mode='w', prefix='httpd-netcat-', dir=os.getcwd(), delete=False)
        try:
            self.httpd_netcat.close()
            os.chmod(self.httpd_netcat.name, stat.S_IRUSR|stat.S_IWUSR|stat.S_IXUSR)
            qemuboot_conf = os.path.join(self.image_dir_test,
                                         '%s-%s.qemuboot.conf' % (self.IMAGE_PN, self.BB_VARS['MACHINE']))
            with open(qemuboot_conf) as f:
                conf = f.read()
            with open(qemuboot_conf, 'w') as f:
                f.write('\n'.join([x for x in conf.splitlines() if not x.startswith('qb_slirp_opt')]))
                f.write('\nqb_slirp_opt = -netdev user,id=net0,guestfwd=tcp:%s-cmd:%s\n' % \
                        (self.HTTPD_SERVER, self.httpd_netcat.name))
            with super().boot_image(ssh=False,
                                    runqemuparams='ovmf slirp nographic',
                                    image_fstype='wic') as qemu:
                yield qemu
        finally:
            os.unlink(self.httpd_netcat.name)

    @contextlib.contextmanager
    def start_httpd(self):
        """
        Bring up the HTTP server when entering the context and shut it down when done.
        """

        # netcat can't be assumed to be present. Build and use socat instead.
        # It's a bit more complicated but has the advantage that it is in OE-core.
        socat = os.path.join(self.BB_VARS['RECIPE_SYSROOT_NATIVE'], 'usr', 'bin', 'socat')
        if not os.path.exists(socat):
            bitbake('socat-native:do_addto_recipe_sysroot', output_log=self.logger)
        self.assertExists(socat, 'socat-native was not built as expected')

        with HTTPServer(self.REPO_DIR, self.logger) as httpd:
            with open(self.httpd_netcat.name, 'w') as f:
                f.write('''#!/bin/sh
exec %s 2>/tmp/httpd.log -D -v -d -d -d -d STDIO TCP:localhost:%d
''' % (socat, httpd.port))
            yield httpd


    def update_image(self, qemu):
        # We need to bring up some simple HTTP server for the
        # update repo.
        with self.start_httpd() as self.httpd:
            # Now run the real update command inside the virtual machine.
            return self.update_image_via_http(qemu)

    def update_image_via_http(self, qemu):
        """
        Called by update_image() with the HTTPD server running.
        """
        return False

