import time

from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import run_as, add_group, add_user, remove_user


class IotvtClientTest(oeRuntimeTest):
    """
    Contains iotivity client testcases
    @class IotvtClientTest
    """
    @classmethod
    def setUpClass(cls):

        cls.tc.target.run("killall simpleserver")
        cls.tc.target.run("killall simpleclient")
        # add group and non-root user
        add_group("tester")
        add_user("iotivity-tester", "tester")

        # set up firewall
        (status, output) = cls.tc.target.run("cat /proc/sys/net/ipv4/ip_local_port_range")
        port_range = output.split()

        cls.tc.target.run("/usr/sbin/ip6tables -w -A INPUT -s fe80::/10 -p udp -m udp --dport 5683 -j ACCEPT")
        cls.tc.target.run("/usr/sbin/ip6tables -w -A INPUT -s fe80::/10 -p udp -m udp --dport 5684 -j ACCEPT")
        cls.tc.target.run("/usr/sbin/ip6tables -w -A INPUT -s fe80::/10 -p udp -m udp --dport %s:%s -j ACCEPT" % (port_range[0], port_range[1]))

        # start server
        server_cmd = "/opt/iotivity/examples/resource/cpp/simpleserver > /tmp/svr_output &"
        run_as("iotivity-tester", server_cmd)
        time.sleep(1)
        # start client to get info
        client_cmd = "/opt/iotivity/examples/resource/cpp/simpleclient > /tmp/output &"
        run_as("iotivity-tester", client_cmd)
        print ("\npatient... simpleclient needs long time for its observation")
        time.sleep(10)
        # If there is no 'Observe is used', give a retry.
        (status, output) = cls.tc.target.run('cat /tmp/output')
        if "Observe is used." in output:
            pass
        else:
            cls.tc.target.run("killall simpleserver")
            cls.tc.target.run("killall simpleclient")
            time.sleep(2)
            (status, output) = cls.tc.target.run(server_cmd)
            cls.tc.target.run(client_cmd)
            time.sleep(10)
        # Retry ends.

    @classmethod
    def tearDownClass(cls):

        remove_user("iotivity-tester")
        cls.tc.target.run("killall simpleserver")
        cls.tc.target.run("killall simpleclient")

    def test_findresource(self):
        '''Check if client is able to discover resource from server
        '''
        (status, output) = self.target.run('cat /tmp/output')
        ret = 0
        if "DISCOVERED Resource" in output:
            pass
        else:
           ret = 1
        self.assertEqual(ret, 0, msg="Error messages: %s" % output)

    def test_get_request_status(self):
        '''Check if GET request finishes successfully
        '''
        (status, output) = self.target.run('cat /tmp/output')
        ret = 0
        if "GET request was successful" in output:
            pass
        else:
           ret = 1
        self.assertEqual(ret, 0, msg="Error messages: %s" % output)

    def test_put_request_status(self):
        '''Check if PUT request finishes successfully
        '''
        (status, output) = self.target.run('cat /tmp/output')
        ret = 0
        if "PUT request was successful" in output:
            pass
        else:
           ret = 1
        self.assertEqual(ret, 0, msg="Error messages: %s" % output)

    def test_server_status(self):
        '''Check if server doesn't crash after timeout
        '''
        time.sleep(2)
        # check if simpleserver is there
        (status, output) = self.target.run('ps')
        self.assertEqual(output.count("simpleserver"), 1, msg="Error messages: %s" % output)

    def test_observer(self):
        '''Check if Observe is used
        '''
        (status, output) = self.target.run('cat /tmp/output')
        ret = 0
        if "Observe is used." in output:
            pass
        else:
           ret = 1
        self.assertEqual(ret, 0, msg="Error messages: %s" % output)
