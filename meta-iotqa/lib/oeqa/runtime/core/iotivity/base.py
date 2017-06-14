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
        port_range = "%s:%s" % tuple(output.split())

        iptables_cmd = "/usr/sbin/ip6tables -w -A INPUT -s fe80::/10 \
                -p udp -m udp --dport %s -j ACCEPT"
        cls.tc.target.run(iptables_cmd % "5683")
        cls.tc.target.run(iptables_cmd % "5684")
        cls.tc.target.run(iptables_cmd % port_range)

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

        remove_user("iotivity-tester")
        cls.tc.target.run("killall simpleserver simpleclient")
