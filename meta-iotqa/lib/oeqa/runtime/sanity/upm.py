# Copyright (C) 2017 Intel Corporation
#
# Author Simo Kuusela <simo.kuusela@intel.com>
#
# Released under the MIT license (see COPYING.MIT)

import os
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import get_files_dir

class UpmTest(oeRuntimeTest):

    def setUp(self):
        (status, output) = self.target.run('mkdir -p /opt/upm-test')
        (status,output) = self.target.copy_to(os.path.join(get_files_dir(),
                          'upm_test'), "/opt/upm-test/")
    def tearDown(self):
        (status, output) = self.target.run('rm -r /opt/upm-test')

    def test_upm_import(self):
        '''
        Test if upm can be imported in C
        '''
        (status, output) = self.target.run("/opt/upm-test/upm_test")

        self.assertEqual(status, 0, msg="Error messages: %s" % output)
