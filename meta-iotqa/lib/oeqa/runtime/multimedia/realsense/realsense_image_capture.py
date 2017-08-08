import os
from oeqa.oetest import oeRuntimeTest


class RealsenseHeadlessTest(oeRuntimeTest):
    def test_realsense_image_capture(self):
        # First make sure that uvcvideo module is loaded.
        (status, output) = self.target.run('modprobe uvcvideo')
        self.assertEqual(status, 0, msg="Error module not loaded: %s" % output)
        # Capture DEPTH image
        (status, output) = self.target.run('cd /tmp && cpp-headless')
        if status == 1:
            # There might not be correct HW connected.
            self.assertEqual(output, "There are 0 connected RealSense devices.", msg="Error messages: %s" % output)
        else:
            # Checking file present
            file = '/tmp/cpp-headless-output-DEPTH.png'
            if not os.path.exists(file):
                raise Exception('Failed to find image file (%s).' % file)
            self.assertEqual(status, 0, msg="Error messages: %s" % output)