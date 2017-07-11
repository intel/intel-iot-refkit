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
# Ismo Puustinen <ismo.puustinen@intel.com>
#
# Based on meta/lib/oeqa/selftest/* and meta-refkit/lib/oeqa/selftest/*

"""Tests for Reference Kit image licensing. Contains a test case for
computer vision production image without GPLv3 components."""

# Important: This test does by no means guarantee that there is license
# compliance. Having the license compatibility rules in a map is not precise
# enough, and many licenses are just omitted. This test is just meant to help
# detect obvious image problems, and it might not do even that in all cases.
# Especially the dual-licensing rules are not very accurate due to the way
# Bitbake recipes express dual-licensing and multi-licensing.

from oeqa.selftest.case import OESelftestTestCase
from oeqa.utils.commands import runCmd, bitbake, get_bb_var, get_bb_vars, runqemu
import glob
import sys
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)) + '/../../../')
import licensecheck

class LicensingTest(OESelftestTestCase):
    """Licensing test class."""

    def _analyzePackages(self, packageNames, whitelistFile, prohibited):
        checker = licensecheck.LicenseCheck(whitelistFile, prohibited)

        # Process packages which are installed to the image.

        for name in packageNames:
            print("Processing package %s..." % name)

            # We can safely skip the kernel modules, also works around kernel
            # naming issues.
            if name.startswith("kernel"):
                continue

            # Pam has some packaging issues, leading to "package not
            # found" error messages.
            if name.startswith("libpam") or name.startswith("pam"):
                continue

            # Packagegroups do not have licensing in the sense that we
            # are interested in.
            if name.startswith("packagegroup"):
                continue

            # Lots of custom licenses, can't really be automatically
            # checked.
            if name.startswith("linux-firmware"):
                continue

            self.assertTrue(checker.testPackage(name), msg="License check for package %s failed" % name)

    def _get_latest_manifest(self, imagename, deploydir):
        # A hack for finding the correct package.manifest for the image we just
        # baked. Assume that has the latest timestamp. First, remove the
        # timestamp from image name:
        imagename_without_timestamp = ("-").join(imagename.split("-")[:-1])
        # Find the corresponding files:
        path = os.path.join(deploydir, "licenses", imagename_without_timestamp)
        # Sort them (by time stamp):
        candidates = glob.glob(path + "*")
        candidates.sort()
        # Get the latest:
        manifestdir = candidates[-1]

        return os.path.join(manifestdir, "package.manifest")

    def test_check_computervision_licensing(self, test_image='refkit-image-computervision'):

        """ Check that computer vision production build image can be
            made without using GPLv3 family licenses in any component.
        """

        print("testing: %s" % test_image)

        # Create the test image (rootfs is enough).
        print('Building test image (%s)...' % test_image)

        # Get variables from BB and initialize package list.
        bb_vars = get_bb_vars(["DEPLOY_DIR", "IMAGE_NAME", "META_REFKIT_BASE", "META_REFKIT_CORE_BASE"], test_image)
        deploydir = bb_vars["DEPLOY_DIR"]
        imagename = bb_vars["IMAGE_NAME"]
        basedir = bb_vars["META_REFKIT_BASE"]
        coredir = bb_vars["META_REFKIT_CORE_BASE"]

        self.append_config('IMAGE_MODE="production"')
        self.append_config('IMAGE_MODE_SUFFIX="-production"')
        self.append_config('REFKIT_DMVERITY_PRIVATE_KEY = "' + os.path.join(coredir, 'files/dm-verity/private.pem') + '"')
        self.append_config('REFKIT_DMVERITY_PASSWORD = "pass:refkit"')

        # Create the root filesystem. It's enough for getting a package
        # list.
        bitbake('-c rootfs %s' % test_image, output_log=self.logger)

        # Find package list manifest.
        manifest = self._get_latest_manifest(imagename, deploydir)
        self.assertTrue(os.path.isfile(manifest), msg="No manifest file created for image. It should have been created in %s" % manifest)

        # Find whitelist.
        whitelist = os.path.join(basedir, "../meta-iotqa/scripts/contrib/licensetree-whitelist.txt")
        self.assertTrue(os.path.isfile(whitelist), msg="Whitelist file not found. It should have been in %s" % whitelist)

        lines = []

        with open(manifest) as f:
            lines = f.readlines()

        packageNames = [line.split()[0] for line in lines]

        # GPLv3 and LGPLv3 are not allowed in this image.
        prohibited=["GPLv3", "LGPLv3"]

        self._analyzePackages(packageNames, whitelist, prohibited)

    def test_check_gateway_licensing(self):
        test_image = 'refkit-image-gateway'
        self.test_check_computervision_licensing(test_image) 
