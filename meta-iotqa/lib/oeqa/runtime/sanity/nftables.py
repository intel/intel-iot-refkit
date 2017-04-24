import os
import subprocess
from time import sleep
from oeqa.oetest import oeRuntimeTest

class NftablesTest(oeRuntimeTest):

    def check_ssh_connection(self):
        '''Check SSH connection to DUT port 2222'''
        process = subprocess.Popen(("ssh -o UserKnownHostsFile=/dev/null " \
                                    "-o ConnectTimeout=3 " \
                                    "-o StrictHostKeyChecking=no root@" + \
                                    self.target.ip +" -p 2222 ls").split(),
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
        output, err = process.communicate()
        output = output.decode("utf-8")
        returncode = process.returncode
        return returncode, output

    def add_test_table(self):
        self.target.run("nft add table ip test")
        self.target.run("nft add chain ip test input {type filter hook input priority 0\;}")
        self.target.run("nft add chain ip test donothing")
        self.target.run("nft add chain ip test prerouting {type nat hook prerouting priority 0 \;}")
        self.target.run("nft add chain ip test postrouting {type nat hook postrouting priority 100 \;}")

    def delete_test_table(self):
        self.target.run("nft delete table ip test")

    def test_reject(self):
        '''Test rejecting SSH with nftables'''
        self.add_test_table()
        self.target.run("nft add rule ip test input tcp dport 2222 reject")
        self.target.run("nft add rule ip test input goto donothing")
        returncode, output = self.check_ssh_connection()
        self.delete_test_table()
        self.assertIn("Connection refused", output, msg="Error message: %s" % output)

    def test_drop(self):
        '''Test dropping SSH with nftables'''
        self.add_test_table()
        self.target.run("nft add rule ip test input tcp dport 2222 drop")
        self.target.run("nft add rule ip test input goto donothing")
        returncode, output = self.check_ssh_connection()
        self.delete_test_table()
        self.assertIn("Connection timed out", output, msg="Error message: %s" % output)

    def test_redirect(self):
        '''Test redirecting port'''
        # Check that SSH can't connect to port 2222
        returncode, output = self.check_ssh_connection()
        self.assertNotEqual(returncode, 0, msg="Error message: %s" % output)

        self.add_test_table()
        self.target.run("nft add rule ip test prerouting tcp dport 2222 redirect to 22")
        # Check that SSH can connect to port 2222
        returncode, output = self.check_ssh_connection()
        self.assertEqual(returncode, 0, msg="Error message: %s" % output)

        self.delete_test_table()
        # Check that SSH can't connect to port 2222
        returncode, output = self.check_ssh_connection()
        self.assertNotEqual(returncode, 0, msg="Error message: %s" % output)
