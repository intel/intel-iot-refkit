"""
Classes:

    IotvtClientTest - Contains iotivity client testcases.
"""

import time

from .base import IotvtRuntimeTest

class IotvtClientTest(IotvtRuntimeTest):
    """
    @class IotvtClientTest
    """

    def _test_findstring(self, sstr):
        (status, __) = self.target.run('grep "%s" /tmp/output' % sstr)
        self.assertEqual(status, 0, msg="Failed to find \"%s\" in file" % sstr)

    def test_findresource(self):
        '''Check if client is able to discover resource from server
        '''
        self._test_findstring("DISCOVERED Resource")

    def test_get_request_status(self):
        '''Check if GET request finishes successfully
        '''
        self._test_findstring("GET request was successful")

    def test_put_request_status(self):
        '''Check if PUT request finishes successfully
        '''
        self._test_findstring("PUT request was successful")

    def test_server_status(self):
        '''Check if server doesn't crash after timeout
        '''
        time.sleep(2)
        # check if simpleserver is there
        (status, __) = self.target.run('ps | grep simpleserver | grep -v grep')
        self.assertEqual(status, 0, msg="simpleserver is not running")

    def test_observer(self):
        '''Check if Observe is used
        '''
        self._test_findstring("Observe is used.")
