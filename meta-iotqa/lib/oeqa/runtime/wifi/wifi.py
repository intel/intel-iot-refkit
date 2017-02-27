import time
import os
from oeqa.utils.helper import shell_cmd_timeout

class WiFiFunction(object):

    service = ""
    log = ""
    def __init__(self, target):
        self.target = target
        # un-block software rfkill lock
        self.target.run('rfkill unblock all')

    def target_collect_info(self, cmd):
        (status, output) = self.target.run(cmd)
        self.log = self.log + "\n\n[Debug] Command output --- %s: \n" % cmd
        self.log = self.log + output

    def enable_wifi(self):
        # Enable WiFi
        (status, output) = self.target.run('connmanctl enable wifi')
        assert status == 0, "Error messages: %s" % output
        time.sleep(1)

    def disable_wifi(self):
        (status, output) = self.target.run('connmanctl disable wifi')
        assert status == 0, "Error messages: %s" % output
        # sleep some seconds to ensure disable is done
        time.sleep(2)

    def scan_wifi(self, ap_type, ssid):
        if (ap_type == "hidden"):
            ssid = "hidden_managed_psk"
        elif (ap_type == "hidden-wep"):
            ssid = "hidden_managed_wep"
        # Retry 4 times scan if needed
        retry = 0
        while (retry < 4):
            (status, output) = self.target.run('connmanctl scan wifi')
            assert status == 0, "Error messages: %s" % output
            (status, output) = self.target.run("connmanctl services | grep %s" % ssid)
            retry = retry + 1
            if (status == 0):
                break
            else:
                self.target_collect_info("connmanctl services")
        # Collect info
        self.target_collect_info("ifconfig")
        assert status == 0, "Not found hidden AP service" + self.log

        if "hidden" in ap_type:
            return output.strip()
        elif (ap_type == "broadcast"):
            return output.split("\n")[0].split(" ")[-1]

    def connect_wifi(self, ap_type, ssid, pwd):
        '''
        Connmanctl to connect wifi AP
        '''
        target_ip = self.target.ip
        for i in range(3):
            service = self.scan_wifi(ap_type, ssid)
            # Do connection
            if (ap_type == "broadcast"):
                exp = os.path.join(os.path.dirname(__file__), "files/wifi_connect.exp")
                cmd = "expect %s %s %s %s %s" % (exp, target_ip, "connmanctl", service, pwd)
            elif "hidden" in ap_type:
                exp = os.path.join(os.path.dirname(__file__), "files/wifi_hidden_connect.exp")
                cmd = "expect %s %s %s %s %s %s" % (exp, target_ip, "connmanctl", service, ssid, pwd)
            else:
                assert False, "ap_type must be broadcast or hidden, check config"
            # execute connection expect script
            status, output = shell_cmd_timeout(cmd, timeout=60)
            if status == 2:
                break
        if type(output) is bytes:
            output = output.decode("ascii")
        assert status == 2, "Error messages: %s" % output

    def get_wifi_ipv4(self):
        '''
        Get wifi ipv4 address
        '''
        time.sleep(3)
        # Check ip address by ifconfig command
        wifi_interface = "nothing"
        (status, wifi_interface) = self.target.run("ifconfig | grep '^wlp\|^wlan' | awk '{print $1}'")
        (status, output) = self.target.run("ifconfig %s | grep 'inet addr:'" % wifi_interface)
        self.target_collect_info("ifconfig")
        assert status == 0, "Error messages: %s" % self.log
        return output.split()[1].split(':')[1]

    def wifi_ip_check(self):
        '''
        Check if the target gets ip address
        '''
        time.sleep(3)
        # Check ip address by ifconfig command
        wifi_interface = "nothing"
        (status, wifi_interface) = self.target.run("ifconfig | grep '^wlp\|^wlan' | awk '{print $1}'")
        (status, output) = self.target.run("ifconfig %s | grep 'inet addr:'" % wifi_interface)
        assert status == 0, "Error messages: %s" % output
        # Collect info
        self.target_collect_info("ifconfig")

        assert status == 0, "IP check failed" + self.log

    def connect_without_password(self, ssid):
        '''
        Connmanctl to connect wifi AP without password
        '''
        self.target.run('connmanctl scan wifi')
        time.sleep(1)
        self.target_collect_info('connmanctl services')
        (status, service) = self.target.run('connmanctl services | grep "%s"' % ssid)
        time.sleep(1)
        assert status == 0, "Do not get AP service: %s" % self.log
        # Directly execute connmanctl to connect AP
        (status, service) = self.target.run('connmanctl connect %s' % service)
        time.sleep(10)
        self.wifi_ip_check()

    def check_internet_connection(self, url):
        '''
        Check if the target is able to connect to internet by wget
        '''
        # wget internet content
        self.target.run("rm -f index.html")
        time.sleep(1)
        for i in range(3):
            (status, output) = self.target.run("wget %s" % url, timeout=100)
            if status == 0:
                break
            time.sleep(3)
        self.target_collect_info("route")
        assert status == 0, "Error messages: %s" % self.log

    def execute_connection(self, ap_type, ssid, pwd):
        '''
        Do a full round of wifi connection without disable
        '''
        self.enable_wifi()
        self.connect_wifi(ap_type, ssid, pwd)
        self.wifi_ip_check()

    def ipv4_ssh_to(self, ipv4):
        '''
        On main target, ssh to second
        '''
        ssh_key = os.path.join(os.path.dirname(__file__), "../bluetooth/files/refkit_qa_rsa")
        self.target.copy_to(ssh_key, "/tmp/")
        self.target.run("chmod 400 /tmp/refkit_qa_rsa")

        exp = os.path.join(os.path.dirname(__file__), "files/ssh_to.exp")
        exp_cmd = 'expect %s %s %s' % (exp, self.target.ip, ipv4)
        (status, output) = shell_cmd_timeout(exp_cmd)
        if type(output) is bytes:
            output = output.decode("ascii")
        assert status == 2, "Error messages: %s" % output

    def scp_to(self, file_path, ipv4):
        '''
        On main target, scp file to second
        '''
        # This function assumes two devices already get ssh-key exchanged.
        scp_cmd = 'scp -i /tmp/refkit_qa_rsa %s root@%s:/home/root/' % (file_path, ipv4)
        (status, output) = self.target.run(scp_cmd, timeout=2000)
        assert status == 0, "Scp fails: %s" % output
