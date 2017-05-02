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

"""
Test cases that verify certain aspects of meta-refkit-extra
in relation to meta-refkit. They need to be here because
meta-refkit-extra is not enabled by default and thus
tests defined there wouldn't be found.
"""

import re

from oeqa.selftest.case import OESelftestTestCase
from oeqa.utils.commands import runCmd, bitbake, get_bb_var

class MetaRefkitExtra(OESelftestTestCase):
    """
    These tests must run in a build configuration that does *not* have
    meta-refkit-extra.
    """

    def setUpLocal(self):
        """
        This code is executed before each test method.
        It verifies that meta-refkit-extra is not active.
        """

        result = runCmd('bitbake-layers show-layers')
        for layer, path, pri in re.findall(r'^(\S+)\s+(.*?)\s+(\d+)$', result.output, re.MULTILINE):
            if layer == 'meta-refkit-extra':
                self.skipTest('meta-refkit-extra already in bblayers.conf')
            if layer == 'meta-refkit':
                self.refkit_extra_path = path + '/../meta-refkit-extra'
        self.extra_conf = "require conf/distro/include/refkit-extra.conf"
        self.image_dir = get_bb_var('DEPLOY_DIR_IMAGE')
        self.machine = get_bb_var('MACHINE')

    def enable_refkit_extra(self):
        '''
        Adds the meta-refkit-extra layer and enables its content.
        Will be undone after the test completes.
        '''
        self.write_bblayers_config('REFKIT_LAYERS += "%s"' % self.refkit_extra_path)
        self.write_config(self.extra_conf)

    def test_build_computervision(self):
        """
        Build an image with the extra packages mentioned in meta-refkit-extra/doc/computervision.rst.
        """
        self.enable_refkit_extra()
        image = 'refkit-image-common'
        packages = 'caffe-imagenet-model python3-pyrealsense opencv'
        result = bitbake(image, postconfig='''
REFKIT_IMAGE_EXTRA_INSTALL = "%s"
        ''' % packages)

        # Ensure that the packages really were installed.
        manifest = os.path.join(self.image_dir, '%s-%s.manifest' % (image, self.machine))
        with open(manifest) as f:
            content = f.read()
            missing = []
            for package in packages.split():
                if not package in content.split():
                    missing.append(package)
            if missing:
                self.fail('%s not installed in %s:\n%s' % (missing, manifest, content))
