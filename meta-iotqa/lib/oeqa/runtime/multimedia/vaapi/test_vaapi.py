from oeqa.oetest import oeRuntimeTest

class VaapiGstreamerCommandlineTest(oeRuntimeTest):
    def test_gst_vaapi_can_decode(self):
        (status, output) = self.target.run('gst-inspect-1.0 filesrc location=./files/test.mp4 !qtdemux ! vaapidecodebin ! vaapisink')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

