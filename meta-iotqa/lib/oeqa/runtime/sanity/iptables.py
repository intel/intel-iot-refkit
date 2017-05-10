import os
import subprocess
from time import sleep
from oeqa.oetest import oeRuntimeTest

class IptablesTest(oeRuntimeTest):

    test_path = "/opt/iptables-test/"
    reject_script = os.path.join(os.path.dirname(__file__),"files","iptables_reject.sh")
    drop_script = os.path.join(os.path.dirname(__file__),"files","iptables_drop.sh")

    def setUp(self):
        # Copy test scripts to device
        self.target.run("mkdir -p " + self.test_path)
        self.target.copy_to(self.reject_script, self.test_path)
        self.target.copy_to(self.drop_script, self.test_path)

    def tearDown(self):
        self.target.run("rm -r " + self.test_path)

    def test_reject(self):
        '''
        Test rejecting SSH with iptables
        '''
        # Check that SSH can connect
        (status, output) = self.target.run("ls")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

        # Check that SSH gets rejected
        self.target.run("nohup " + self.test_path + "iptables_reject.sh &>/dev/null &")
        sleep(1)
        try:
            output = subprocess.check_output(("ssh -o UserKnownHostsFile=/dev/null " \
                                            "-o StrictHostKeyChecking=no root@" \
                                            + self.target.ip + " ls").split(),
                                            stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as error:
            output = error.output
        output = output.decode("utf-8")
        self.assertIn("Connection refused", output, msg="Error messages: %s" % output)
        sleep(5) # Wait for script to make iptables accept SSH again

        # Check that SSH can connect
        (status, output) = self.target.run("ls")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_drop(self):
        '''
        Test dropping SSH with iptables
        '''
        # Check that SSH can connect
        (status, output) = self.target.run("ls")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

        # Check that SSH gets dropped
        self.target.run("nohup " + self.test_path + "iptables_drop.sh &>/dev/null &")
        sleep(1)
        try:
            output = subprocess.check_output(("ssh -o UserKnownHostsFile=/dev/null " \
                                            "-o ConnectTimeout=5 " \
                                            "-o StrictHostKeyChecking=no root@" \
                                            + self.target.ip + " ls").split(),
                                            stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as error:
            output = error.output
        output = output.decode("utf-8")
        self.assertIn("Connection timed out", output, msg="Error messages: %s" % output)
        sleep(10) # Wait for script to make iptables accept SSH again

        # Check that SSH can connect
        (status, output) = self.target.run("ls")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
