from oeqa.oetest import oeRuntimeTest

class RealsenseHeadlessTest(oeRuntimeTest):
    def test_realsense_headless(self):
        # First make sure that uvcvideo module is loaded.
        (status, output) = self.target.run('modprobe uvcvideo')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        # Run an example test from librealsense-examples.
        (status, output) = self.target.run('cpp-headless')
        if status == 1:
            # There might not be correct HW connected.
            self.assertEqual(output, "There are 0 connected RealSense devices.", msg="Error messages: %s" % output)
        else:
            self.assertEqual(status, 0, msg="Error messages: %s" % output)
