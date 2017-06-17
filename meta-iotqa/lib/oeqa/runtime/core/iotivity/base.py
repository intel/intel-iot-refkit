"""
Classes:

    IotvtRuntimeTest - Base class for iotivity tests.
"""

import time

from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import run_as, add_group, add_user, remove_user

class IotvtRuntimeTest(oeRuntimeTest):
    """
    @class IotvtRuntimeTest
    """

    @classmethod
    def setUpClass(cls):

        # Kill simpleserver and simpleclient
        cls.tc.target.run("killall simpleserver simpleclient")

        # Create test user
        add_group("tester")
        add_user("iotivity-tester", "tester")

        # Set up firewall
        port_range_cmd = "cat /proc/sys/net/ipv4/ip_local_port_range"
        (status, output) = cls.tc.target.run(port_range_cmd)
        port_range = output.split()

        cls.tc.target.run("/usr/sbin/nft add chain inet filter iotivity { type filter hook input priority 0\; }")
        cls.tc.target.run("/usr/sbin/nft add rule inet filter iotivity ip6 saddr fe80::/10 udp dport {5683, 5684, %s-%s} mark set 1" % (port_range[0], port_range[1]))

        # Start server
        resource_cmd = "/opt/iotivity/examples/resource/cpp/%s > /tmp/%s &"
        run_as("iotivity-tester", resource_cmd % ("simpleserver","svr_output"))
        time.sleep(1)

        # Start client to get info
        run_as("iotivity-tester", resource_cmd % ("simpleclient","output"))
        print ("\npatient... simpleclient needs long time for its observation")
        time.sleep(10)

        # If there is no 'Observe is used', give a retry.
        (status, __) = cls.tc.target.run('grep "Observe is used." /tmp/output')
        if status != 0:
            cls.tc.target.run("killall simpleserver simpleclient")
            time.sleep(2)
            cls.tc.target.run(resource_cmd % ("simpleserver","svr_output"))
            cls.tc.target.run(resource_cmd % ("simpleclient","output"))
            time.sleep(10)

    @classmethod
    def tearDownClass(cls):

        cls.tc.target.run("/usr/sbin/nft flush chain inet filter iotivity")
        cls.tc.target.run("/usr/sbin/nft delete chain inet filter iotivity")
        remove_user("iotivity-tester")
        cls.tc.target.run("killall simpleserver simpleclient")
