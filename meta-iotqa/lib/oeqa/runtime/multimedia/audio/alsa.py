# Copyright (C) 2017 Intel Corporation
#
# Author Simo Kuusela <simo.kuusela@intel.com>
#
# Released under the MIT license (see COPYING.MIT)

from oeqa.oetest import oeRuntimeTest

class AlsaTest(oeRuntimeTest):

    def test_speaker_test(self):
        '''
        Test audio with speaker-test
        '''
        status, output = self.target.run("speaker-test -D hdmi:CARD=PCH,DEV=0 -c 2 -l 1")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
