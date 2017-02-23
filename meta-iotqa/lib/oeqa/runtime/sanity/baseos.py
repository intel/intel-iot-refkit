#[PROTEXCAT]
#\License: ALL RIGHTS RESERVED
#\Author: Wang, Jing <jing.j.wang@intel.com>

from oeqa.oetest import oeRuntimeTest
from oeqa.utils.decorators import tag
import re

@tag(TestType="FVT", FeatureID="IOTOS-638")
class BaseOsTest(oeRuntimeTest):
    '''Base os health check
    @class BaseOsTest
    '''
    def test_baseos_dmesg(self):
        '''check dmesg command
        @fn test_baseos_dmesg
        @param self
        @return
        '''
        (status, output) = self.target.run('dmesg')
        ##
        # TESTPOINT: #1, test_baseos_dmesg
        #
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_baseos_lsmod(self):
        '''check lsmod command
        @fn test_baseos_lsmod
        @param self
        @return
        '''
        (status, output) = self.target.run('lsmod')
        ##
        # TESTPOINT: #1, test_baseos_lsmod
        #
        # lsmod should show at least 1 module
        if output.count('\n') > 0:
            pass
        else:
            status=1
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_baseos_ps(self):
        '''check ps command
        @fn test_baseos_ps
        @param self
        @return
        '''
        (status, output) = self.target.run('ps')
        ##
        # TESTPOINT: #1, test_baseos_ps
        #
        # ps should show at least 1 process
        if output.count('\n') > 0:
            pass
        else:
            status=1
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_baseos_df(self):
        '''check df command
        @fn test_baseos_df
        @param self
        @return
        '''
        (status, output) = self.target.run('df')
        ##
        # TESTPOINT: #1, test_baseos_df
        #
        # df should show at least 1 mounting point
        if output.count('\n') > 0:
            pass
        else:
            status=1
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_baseos_systemd_process(self):
        '''check systemd process
        @fn test_baseos_systemd_process
        @param self
        @return
        '''
        (status, output) = self.target.run("ls -l /proc/1/exe")
        ##
        # TESTPOINT: #1, test_baseos_systemd_process
        #
        if output.endswith("systemd"):
            pass
        else:
            status=1
        self.assertEqual(status, 0, msg="Error messages: %s" % output)

    def test_baseos_systemd_boot_error(self):
        ''' check systemd boot journal error'''
        known_issues_list = [
            "GPT: Use GNU Parted to correct GPT errors",
            # Error from Beaglebone Black USB keyboard or ethernet emulation
            "0003:8086:BEEF.0001",
            # Harmless error
            "[drm] parse error at position 4 in video mode 'efifb'",
            # Errors from bad Intel(r) 500 series support
            "ACPI Error: Could not enable PowerButton event",
            "button: probe of LNXPWRBN:00 failed with error -22",
            "Direct firmware load for i915/bxt_dmc_ver1_07.bin failed",
            "Direct firmware load for iwlwifi-8000C",
            "ACPI Error: Could not enable RealTimeClock event",
            "hci_intel: probe of INT33E1:00 failed with error -2",
            "Error changing net interface name 'usb0' to",
            "*ERROR* dp aux hw did not signal timeout",
            # Bug 11105, in Refkit bugzilla
            "file /var/lib/alsa/asound.state lock error"
            ]
        self.longMessage = True
        cmd = "journalctl -ab"
        (status, output) = self.target.run("journalctl -ab")
        self.assertEqual(status, 0, "Fail to run %s,status is %s, output is: %s\n"
                                              % (cmd,status,output))

        self.assertTrue(output.strip(), "No systemd journal log")
        journal = output
        errors = []
        for line in output.split('\n'):
            if 'error' in line.lower():
                flag = 0
                for issue in known_issues_list:
                    if issue in line:
                        flag = 1
                        break
                if flag == 0 :
                    errors.append(line)

        self.assertEqual(len(errors), 0, "Errors in boot log:\n %s, \nFull log:\n %s"
                                  % ("\n".join(errors), journal))
