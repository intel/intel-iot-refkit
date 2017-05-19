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

"""Test cases for refkit content against Poky"""

import os
import re
import shutil
import sys

from oeqa.selftest.base import oeSelfTest
from oeqa.utils.commands import runCmd, bitbake, get_bb_var, get_bb_vars, runqemu
from oeqa.utils.decorators import testcase

class RefkitPokyMeta(type):
    """
    Generates different instances of test_compat_meta_<layer> for each refkit layer.
    """
    def __new__(mcs, name, bases, dict):
        def gen_test(refkit_layer):
            def test(self):
                """
                Test Yocto Compatible 2.0 status of each refkit layer.
                This covers also:
                - proper declaration of dependencies (because 'yocto-compat-layer.py --dependency' adds those)
                - parse and dependencies ('bitbake -S none world' must work)
                """
                cmd = "yocto-compat-layer.py --dependency %s -- %s" % (' '.join(self.layers.values()),
                                                                       self.layers[refkit_layer])
                result = runCmd(cmd, **self.build_options)
                # yocto-compat-layer.py does not return error codes (YOCTO #11482), so we have to guess.
                if 'INFO: FAILED' in result.output:
                    # There's no point in dumping the full command, because the environment for
                    # invoking it wouldn't be right anyway.
                    self.fail(result.output)
            return test

        layers = {}
        result = runCmd('bitbake-layers show-layers')
        for layer, path, pri in re.findall(r'^(\S+) +([^\n]*?) +(\d+)$', result.output, re.MULTILINE):
            layers[layer] = path
        # meta-poky should not be active. We expect it next to the meta-refkit layer.
        if not 'meta-poky' in layers:
            layers['meta-poky'] = os.path.join(os.path.dirname(layers['meta-refkit']), 'meta-yocto', 'meta-poky')
        dict['layers'] = layers
        for refkit_layer in [x for x in layers.keys() if x.startswith('meta-refkit')]:
            test_name = 'test_compat_%s' % refkit_layer.replace('-', '_')
            dict[test_name] = gen_test(refkit_layer)
        return type.__new__(mcs, name, bases, dict)

class TestRefkitPoky(oeSelfTest, metaclass=RefkitPokyMeta):
    """
    Tests content from refkit against Poky. We do not want to depend on the
    combined poky repo, though, so Poky in this context is OE-core + meta-poky.
    We also pick meta-intel and use MACHINE=intel-corei7-64 because this way
    machine-specific recipes also get tested.

    We limit testing to recipes that are known to work. This is necessary
    because world builds of meta-openembedded tend to break quite often,
    and the test_compat_<layer> tests depend on working world builds. Also
    speeds up testing.
    """

    LOCAL_CONF = '''
MACHINE = "intel-corei7-64"
DISTRO = "poky"
INHERIT += "supported-recipes"
include selftest.inc
'''
    COPY_CONF_VARS = (
        'DL_DIR',
        'SSTATE_DIR',
        'SSTATE_MIRRORS',
        'PREMIRRORS',
        'PRSERV_HOST',
        'SUPPORTED_RECIPES',
        )

    @classmethod
    def setUpClass(cls):
        """Queries the local configuration to find the relevant directories."""
        cls.build_dir = os.getcwd()
        cls.poky_dir = os.path.join(cls.build_dir, 'refkit-poky')
        cls.poky_conf_dir = os.path.join(cls.poky_dir, 'conf')
        result = runCmd('bitbake -e')
        cls.buildvars = {}
        for var, value in re.findall(r'^(\S+)="(.*?)"$', result.output, re.MULTILINE):
            cls.buildvars[var] = value

        # We expect compatlayer in the lib dir of the directory holding yocto-compat-layer.py.
        yocto_compat_layer = shutil.which('yocto-compat-layer.py')
        scripts_path = os.path.dirname(os.path.realpath(yocto_compat_layer))
        # Temporary override: use the copy from meta-refkit.
        scripts_path = os.path.join(cls.layers['meta-refkit'], 'scripts')
        cls.yocto_compat_lib_path = scripts_path + '/lib'

    def setUpLocal(self):
        """Creates a clean build directory with a Poky configuration."""
        if os.path.exists(self.poky_dir):
            shutil.rmtree(self.poky_dir)
        bb.utils.mkdirhier(self.poky_dir)
        bb.utils.mkdirhier(self.poky_conf_dir)
        with open(os.path.join(self.poky_conf_dir, 'local.conf'), 'w') as f:
            f.write(self.LOCAL_CONF)
            for var in self.COPY_CONF_VARS:
                value = self.buildvars.get(var, None)
                if value is not None:
                    f.write('%s = "%s"\n' % (var, value))
        self.poky_layers = ('meta', 'meta-poky', 'meta-intel')
        with open(os.path.join(self.poky_conf_dir, 'bblayers.conf'), 'w') as f:
            f.write('''BBPATH = "${TOPDIR}"
BBFILES ?= ""
''')
            f.write('BBLAYERS = "%s"\n' % (' '.join([self.layers[x] for x in self.poky_layers])))
            f.write('include bblayers.inc\n')

        # supported-recipes.bbclass must be available also with just plain Poky.
        # Here we put it into what will become TOPDIR.
        classes = os.path.join(self.poky_dir, 'classes')
        bb.utils.mkdirhier(classes)
        os.symlink(os.path.join(self.layers['meta-refkit-core'], 'classes', 'supported-recipes.bbclass'),
                   os.path.join(classes, 'supported-recipes.bbclass'))
        lib = os.path.join(self.poky_dir, 'lib')
        bb.utils.mkdirhier(lib)
        for target in ('supportedrecipes.py', 'supportedrecipesreport'):
            os.symlink(os.path.join(self.layers['meta-refkit-core'], 'lib', target),
                       os.path.join(lib, target))

        # BUILDDIR must be set for "yocto-compat-layer.py" to work:
        # it looks for the locked signature file in that directory.
        env = os.environ.copy()
        env['BUILDDIR'] = self.poky_dir
        # We must use our forked yocto-compat-layer.py.
        env['PATH'] = '%s/scripts:%s' % (self.layers['meta-refkit'], env['PATH'])
        self.build_options = {'env': env, 'cwd': self.poky_dir}

    def tearDownLocal(self):
        """Remove temporary build directory."""
        pass
        # shutil.rmtree(self.poky_dir)

    def _poky_builddir(func):
        """Wraps a test function so that it uses the Poky build directory (cwd, config files, BUILDDIR, etc.)."""
        def enter_poky_builddir(self):
            old_env = os.environ.copy()
            old_cwd = os.getcwd()
            old_testinc_path = self.testinc_path
            old_testinc_bblayers_path = self.testinc_bblayers_path
            try:
                os.environ['BUILDDIR'] = self.poky_dir
                os.chdir(self.poky_dir)
                self.testinc_path = os.path.join(self.poky_dir, "conf/selftest.inc")
                self.testinc_bblayers_path = os.path.join(self.poky_dir, "conf/bblayers.inc")

                return func(self)
            finally:
                os.environ = old_env
                os.chdir(old_cwd)
                self.testinc_path = old_testinc_path
                self.testinc_bblayers_path = old_testinc_bblayers_path

        return enter_poky_builddir

    def add_refkit_layers(self):
        """Add all layers also active in the parent refkit build dir."""
        self.append_bblayers_config('BBLAYERS += "%s"' % (' '.join([self.layers[x] for x in self.layers.keys() if x not in self.poky_layers])))

    @_poky_builddir
    def test_refkit_conf_signature(self):
        """Ensure that including the refkit config does not change the signature of other layers."""
        old_path = sys.path
        try:
            sys.path = [self.yocto_compat_lib_path] + sys.path
            import compatlayer

            self.add_refkit_layers()

            # Ignore world build errors, some of the non-refkit layers might be broken.
            old_sigs, _ = compatlayer.get_signatures(self.poky_dir, failsafe=True)
            # Now add refkit-conf.inc, without changing the DISTRO_FEATURES.
            self.append_config('require conf/distro/include/refkit-config.inc')
            curr_sigs, _ = compatlayer.get_signatures(self.poky_dir, failsafe=True)
            msg = compatlayer.compare_signatures(old_sigs, curr_sigs)
            if msg is not None:
                self.fail('Including refkit-config.inc changed signatures.\n%s' % msg)
        finally:
            sys.path = old_path

    @_poky_builddir
    def test_refkit_computervision(self):
        """
        A full image build test of the computer vision image.
        Poky uses sysvinit. Actually building an image runs
        also postinst and various rootfs manipulation code,
        and some of that might assume that systemd is used.
        """
        self.add_refkit_layers()
        bitbake('refkit-image-computervision')
