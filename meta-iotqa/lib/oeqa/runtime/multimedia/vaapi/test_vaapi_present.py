'''
This test suit tests VAAPI is present or not
'''

from oeqa.oetest import oeRuntimeTest

class VAAPITest(oeRuntimeTest):
    def test_vaapi_present(self):
        (status, output) = self.target.run("vainfo")
        self.assertEqual(status, 0, msg="Error messages: VAAPI not Present %s" % output)
