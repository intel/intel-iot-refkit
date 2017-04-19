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
# Humberto Ibarra <humberto.ibarra.lopez@linux.intel.com>

import re
import logging

from oeqa.selftest.base import oeSelfTest
from oeqa.utils.commands import bitbake, runqemu, get_bb_var
from oeqa.utils.decorators import testcase

class RunqemuTests(oeSelfTest):
    """Runqemu test class"""

    image_is_ready = False
    deploy_dir_image = ''

    def setUpLocal(self):
        self.refkit_recipe = 'refkit-image-common'
        self.ovmf_recipe = 'ovmf'
        self.cmd_common = "runqemu ovmf wic slirp nographic serial"

        if not RunqemuTests.image_is_ready:
            RunqemuTests.deploy_dir_image = get_bb_var('DEPLOY_DIR_IMAGE')
            bitbake(self.refkit_recipe)
            bitbake(self.ovmf_recipe)
            RunqemuTests.image_is_ready = True

    @testcase(2001)
    def test_boot_machine(self):
        """Test runqemu machine"""
        with runqemu(self.refkit_recipe, ssh=False, launch_cmd=self.cmd_common) as qemu:
            self.assertTrue(qemu.runner.logged, "Failed: %s" % self.cmd_common)
