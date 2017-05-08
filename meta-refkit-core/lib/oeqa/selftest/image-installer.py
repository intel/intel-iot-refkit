#!/usr/bin/env python
# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
#
# Copyright (c) 2017, Intel Corporation.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# AUTHORS
# Patrick Ohly <patrick.ohly@intel.com>
#
# Based on meta/lib/oeqa/selftest/wic.py by Ed Bartosh <ed.bartosh@linux.intel.com>.

"""Test cases for image-installer.bbclass and refkit-installer-image.bb"""

import os

from glob import glob
from shutil import rmtree,copyfile

from oeqa.selftest.base import oeSelfTest
from oeqa.utils.commands import runCmd, bitbake, get_bb_var, get_bb_vars, runqemu
from oeqa.utils.decorators import testcase


class ImageInstaller(oeSelfTest):
    """
    image-installer.bbclass and refkit-installer-image.bb test class.
    Device paths are based on the assumption that virtio is used.
    """

    image_is_ready = False
    wicenv_cache = {}

    def setUpLocal(self):
        """This code is executed before each test method."""
        self.distro_features = get_bb_var('DISTRO_FEATURES').split()
        self.machine_arch = get_bb_var('MACHINE_ARCH')
        self.image_arch = self.machine_arch.replace('_', '-')
        self.image_dir = get_bb_var('DEPLOY_DIR_IMAGE')
        self.resultdir = os.path.join(get_bb_var('TMPDIR'), 'oeselftest', 'image-installer')

        # Do this here instead of in setUpClass as the base setUp does some
        # clean up which can result in the native tools built earlier in
        # setUpClass being unavailable.
        if not ImageInstaller.image_is_ready:
            targets = 'refkit-installer-image ovmf swtpm-wrappers-native'
            print('Starting: bitbake %s' % targets)
            result = bitbake(targets)
            print(result.output)
            ImageInstaller.image_is_ready = True

        # We create the directory under ${TMPDIR} and thus can avoid
        # deleting it, which is a bit nicer for debugging test failures.
        rmtree(self.resultdir, ignore_errors=True)
        bb.utils.mkdirhier(self.resultdir)

    def create_internal_disk(self):
        """Create a internal-image*.wic in the resultdir that runqemu can use."""
        copyfile(os.path.join(self.image_dir, 'refkit-installer-image-%s.qemuboot.conf' % self.image_arch),
                 os.path.join(self.resultdir, 'internal-image-%s.qemuboot.conf' % self.image_arch))
        for ovmf in glob('%s/ovmf*' % self.image_dir):
            os.symlink(ovmf, os.path.join(self.resultdir, os.path.basename(ovmf)))
        with open(os.path.join(self.resultdir, 'internal-image-%s.wic' % self.image_arch), 'w') as f:
            # empty, sparse file of 8GB
            os.truncate(f.fileno(), 8 * 1024 * 1024 * 1024)

    def do_install(self, fixed_password="", tpm=False):
        self.create_internal_disk()

        if tpm:
            swtpm = glob('tmp-glibc/work/*/swtpm-wrappers-native/1.0-r0/swtpm_setup_oe.sh')
            self.assertEqual(len(swtpm), 1, msg='Expected exactly one swtpm_setup_oe.sh: %s' % swtpm)
            cmd = '%s --tpm-state %s --createek' % (swtpm[0], self.resultdir)
            self.assertEqual(0, runCmd(cmd).status)
            qemuparams_tpm = " -tpmdev emulator,id=tpm0,spawn=on,tpmstatedir=%s,logfile=%s/swtpm.log,path=%s -device tpm-tis,tpmdev=tpm0" % \
                             (self.resultdir, self.resultdir, os.path.join(os.path.dirname(swtpm[0]), 'swtpm_oe.sh'))
        else:
            qemuparams_tpm = ""

        # Install.
        with runqemu('refkit-installer-image', ssh=False,
                     discard_writes=False,
                     qemuparams='-drive if=virtio,file=%s/internal-image-%s.wic,format=raw%s' % (self.resultdir, self.image_arch, qemuparams_tpm),
                     runqemuparams='ovmf slirp',
                     image_fstype='wic') as qemu:
            # Check that we have booted, with dm-verity if enabled.
            cmd = "findmnt / --output SOURCE --noheadings"
            status, output = qemu.run_serial(cmd)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            if 'dm-verity' in self.distro_features:
                self.assertEqual('/dev/mapper/rootfs', output)
            else:
                self.assertIn('vda', output)
            # Now install, non-interactively. Driving the script
            # interactively would be also a worthwhile test...
            cmd = "CHOSEN_INPUT=refkit-image-common-%s.wic CHOSEN_OUTPUT=vdb FORCE=yes %s%simage-installer" % \
                  (self.image_arch,
                   ("FIXED_PASSWORD=%s " % fixed_password) if fixed_password else "",
                   "TPM12=yes " if tpm else "",
                   )
            status, output = qemu.run_serial(cmd, timeout=300)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            bb.note('Installed successfully:\n%s' % output)
            self.assertTrue(output.endswith('Installed refkit-image-common-%s.wic on vdb successfully.' % self.image_arch))

        # Test installation by replacing the normal image with our internal one.
        overrides = {
            'DEPLOY_DIR_IMAGE': self.resultdir,
            'IMAGE_LINK_NAME': 'internal-image-%s' % self.image_arch,
            }
        with runqemu('refkit-installer-image', ssh=False,
                     overrides=overrides,
                     qemuparams=qemuparams_tpm,
                     runqemuparams='ovmf slirp',
                     image_fstype='wic') as qemu:
            # Check that we have booted, without device mapper involved.
            # Can't use the simpler findmnt here.
            cmd = "mount"
            status, output = qemu.run_serial(cmd)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            if fixed_password or tpm:
                # The two are undistinguisable because the only difference is from where
                # the password came. However, when we run with TPM, we expect to have a
                # /dev/tpm0 around.
                self.assertIn('/dev/mapper/rootfs on / ', output)
            else:
                self.assertIn('/dev/vda3 on / ', output)
            if tpm:
                cmd = "ls /dev/tpm0"
                status, output = qemu.run_serial(cmd)
                self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))

    def test_install_no_tpm(self):
        """Test image installation under qemu without virtual TPM"""
        self.do_install()

    def test_install_fixed_password(self):
        """Test image installation under qemu without virtual TPM, using a fixed password"""
        fixed_password = get_bb_var('REFKIT_DISK_ENCRYPTION_PASSWORD')
        if not fixed_password:
            self.skipTest('REFKIT_DISK_ENCRYPTION_PASSWORD not set')
        self.do_install(fixed_password=fixed_password)

    def test_install_tpm(self):
        """Test image installation under qemu without virtual TPM, using a fixed password"""
        self.do_install(tpm=True)
