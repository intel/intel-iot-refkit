import unittest
from oeqa.oetest import oeRuntimeTest, skipModule
from oeqa.utils.decorators import *

def setUpModule():
    if not oeRuntimeTest.hasFeature('flatpak'):
        skipModule("flatpak not enabled, tests skipped")

class SanityTestFlatpak(oeRuntimeTest):
    '''flatpak sanity tests'''

    def test_flatpak_usrmerge(self):
        '''check if / and /usr are properly merged'''
        links = [ '/bin', '/sbin', '/lib', ]
        for l in links:
            (status, output) = self.target.run('readlink %s' % l)
            self.assertEqual(
                status, 0,
                "usrmerge error: %s should be a symbolic link" % l)

    def test_basic_binaries(self):
        '''check if basic flatpak binaries exist'''
        binaries = [
            '/usr/bin/flatpak',
            '/usr/bin/gpgme-tool',
            '/usr/bin/gpg'
        ]
        for b in binaries:
            (status, output) = self.target.run('ls %s' % b)
            self.assertEqual(
                status, 0,
                'flatpak basic binary %s missing' % b)
