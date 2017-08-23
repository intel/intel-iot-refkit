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

from oeqa.selftest.case import OESelftestTestCase
from oeqa.utils.commands import runCmd, bitbake, get_bb_var, get_bb_vars, runqemu


class ImageInstaller(OESelftestTestCase):
    """
    image-installer.bbclass and refkit-installer-image.bb test class.
    Device paths are based on the assumption that virtio is used.
    """

    image_is_ready = False
    wicenv_cache = {}

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.installer_test_vars = get_bb_vars([
            'DEPLOY_DIR_IMAGE',
            'DISTRO_FEATURES',
            'MACHINE_ARCH',
            'TMPDIR',
        ])

    def setUpLocal(self):
        """This code is executed before each test method."""
        self.distro_features = self.installer_test_vars['DISTRO_FEATURES'].split()
        self.machine_arch = self.installer_test_vars['MACHINE_ARCH']
        self.image_arch = self.machine_arch.replace('_', '-')
        self.image_dir = self.installer_test_vars['DEPLOY_DIR_IMAGE']
        self.resultdir = os.path.join(self.installer_test_vars['TMPDIR'], 'oeselftest', 'image-installer')

        # Do this here instead of in setUpClass as the base setUp does some
        # clean up which can result in the native tools built earlier in
        # setUpClass being unavailable.
        if not ImageInstaller.image_is_ready:
            # The tests depend on images done in "development" mode, so set that here
            # temporarily in a way that it overrides some other IMAGE_MODE setting in local.conf.
            self.append_config('IMAGE_MODE_forcevariable = "development"')
            targets = 'refkit-installer-image ovmf swtpm2-wrappers-native'
            result = bitbake(targets, output_log=self.logger)
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
            swtpm = glob('%s/work/*/swtpm2-wrappers-native/1.0-r0/swtpm_setup_oe.sh' % self.installer_test_vars['TMPDIR'])
            self.assertEqual(len(swtpm), 1, msg='Expected exactly one swtpm_setup_oe.sh: %s' % swtpm)
            if tpm == '2.0':
                tpmmode = ' --tpm2'
            else:
                tpmmode = ''
            cmd = '%s %s --tpm-state %s --createek' % (swtpm[0], tpmmode, self.resultdir)
            self.assertEqual(0, runCmd(cmd).status)
            # Comma is the parameter separator in qemu. Double-comma can be used to embed a comma in a parameter,
            # which we need here for the cmd's --ctrl value.
            # --terminate is a workaround for swtpm not doing that automatically when it looses the
            # connection and doesn't have a listenting socket (as in this case here).
            swtpm_log = os.path.join(self.resultdir, 'swtpm.log')
            qemuparams_tpm = " -chardev 'socket,id=chrtpm0,cmd=exec %s socket --terminate --ctrl type=unixio,,clientfd=0 --tpmstate dir=%s --log level=10,,file=%s%s'" % \
                             (os.path.join(os.path.dirname(swtpm[0]), 'swtpm_oe.sh'), self.resultdir, swtpm_log, tpmmode)
            qemuparams_tpm += " -tpmdev emulator,id=tpm0,chardev=chrtpm0 -device tpm-tis,tpmdev=tpm0 "
        else:
            qemuparams_tpm = ""

        # Install.
        with runqemu('refkit-installer-image', ssh=False,
                     discard_writes=False,
                     qemuparams='-drive if=virtio,file=%s/internal-image-%s.wic,format=raw%s' % (self.resultdir, self.image_arch, qemuparams_tpm),
                     runqemuparams='ovmf slirp nographic',
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
                   "TPM=%s " % tpm if tpm else "",
                   )
            status, output = qemu.run_serial(cmd, timeout=300)
            self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
            self.logger.info('Installed successfully:\n%s\n%s' % (cmd, output))
            self.assertTrue(output.endswith('Installed refkit-image-common-%s.wic on vdb successfully.' % self.image_arch))
            if tpm:
                self.assertIn('cryptsetup', output)
                if tpm == '2.0':
                    self.assertIn('tpm2_nvdefine', output)
                else:
                    self.assertIn('tpm_nvdefine', output)

        # Test installation by replacing the normal image with our internal one.
        overrides = {
            'DEPLOY_DIR_IMAGE': self.resultdir,
            'IMAGE_LINK_NAME': 'internal-image-%s' % self.image_arch,
            }
        with runqemu('refkit-installer-image', ssh=False,
                     overrides=overrides,
                     qemuparams=qemuparams_tpm,
                     runqemuparams='ovmf slirp nographic',
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
        # Same fixed password as the one used for development images
        # (see refkit-boot-settings.inc).
        self.do_install(fixed_password="refkit")

    def test_install_tpm12(self):
        """Test image installation under qemu with virtual TPM 1.2, using a fixed password"""
        self.do_install(tpm='1.2')

    def test_install_tpm20(self):
        """Test image installation under qemu with virtual TPM 2.0, using a fixed password"""
        self.do_install(tpm='2.0')
