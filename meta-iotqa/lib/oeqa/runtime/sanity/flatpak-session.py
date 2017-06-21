import unittest
from oeqa.oetest import oeRuntimeTest, skipModule
from oeqa.utils.decorators import *

def setUpModule():
    if not oeRuntimeTest.hasFeature('flatpak-session'):
        skipModule("flatpak not enabled, tests skipped")

class SanityTestFlatpakSession(oeRuntimeTest):
    '''flatpak session sanity tests'''

    def test_session_files(self):
        '''check if flatpak session binaries and service files exist'''
        files = [
            '/usr/bin/flatpak-session',
            '/usr/lib/systemd/system-generators/flatpak-session-enable',
            '/usr/lib/systemd/system/flatpak-image-runtime.service',
            '/usr/lib/systemd/system/flatpak-update.service',
            '/usr/lib/systemd/system/flatpak-session@.service',
            '/usr/lib/systemd/system/flatpak-sessions.target',
        ]
        for f in files:
            (status, output) = self.target.run('ls %s' % f)
            self.assertEqual(
                status, 0,
                'flatpak session binary/file %s missing' % f)
