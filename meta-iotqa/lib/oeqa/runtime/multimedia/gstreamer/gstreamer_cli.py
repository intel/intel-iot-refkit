from oeqa.oetest import oeRuntimeTest

class GstreamerCommandlineTest(oeRuntimeTest):
    def test_gst_inspect_can_detect_existing_element(self):
        (status, output) = self.target.run('gst-inspect-1.0')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

        (status, output) = self.target.run('gst-inspect-1.0 fakesrc')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_gst_launch_can_create_video_pipeline(self):
        (status, output) = self.target.run('gst-launch-1.0 -v fakesrc silent=false num-buffers=3 ! fakesink silent=false')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

