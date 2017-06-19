import tempfile
import os
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import get_files_dir

TESTCMD = b"""
export ROS_ROOT=/opt/ros
export ROS_DISTRO=indigo
export ROS_PACKAGE_PATH=/opt/ros/indigo/share
export PATH=$PATH:/opt/ros/indigo/bin
export LD_LIBRARY_PATH=/opt/ros/indigo/lib
export PYTHONPATH=/opt/ros/indigo/lib/python3.5/site-packages
export ROS_MASTER_URI=http://localhost:11311
export CMAKE_PREFIX_PATH=/opt/ros/indigo
touch /opt/ros/indigo/.catkin
roslaunch refkit_ros_tests helloworld.launch
"""

TESTCMD_PATH = "/home/root/rosinit.sh"

class RosHelloworldTest(oeRuntimeTest):
    def test_ros_helloworld(self):
        self.target.connection.copy_dir_to(os.path.join(get_files_dir(), "opt"), "/opt")
        with tempfile.NamedTemporaryFile() as testcmd:
            testcmd.write(TESTCMD)
            testcmd.flush()
            self.target.copy_to(testcmd.name, TESTCMD_PATH)
        (status, output) = self.target.run("sh %s" % TESTCMD_PATH)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
