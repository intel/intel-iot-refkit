import os
import time
import subprocess
from oeqa.runtime.connectivity.bluetooth import bluetooth
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import shell_cmd_timeout
from oeqa.utils.helper import get_files_dir


class BTStabilityTest(oeRuntimeTest):
    power_cycles = 200

    def setUp(self):
        self.bt = bluetooth.BTFunction(self.target)
        self.bt.target_hciconfig_init()
        self.bt.enable_bluetooth()

    def tearDown(self):
        self.bt.disable_bluetooth()

    def test_bt_onoff_multiple_times(self):
        """
        Use bluetoothctl to power on/off multiple times
        """
        for i in range(1, self.power_cycles):
            self.bt.ctl_power_on()
            self.bt.ctl_power_off()
            if i % 20 == 0:
                print ("Finished %d cycles successfuly." % i)

    def test_bt_visible_onoff_multiple_times(self):
        """
        Use bluetoothctl to turn discoverable on/off multiple times
        """
        self.bt.ctl_power_on()
        for i in range(1, self.power_cycles):
            self.bt.ctl_visible_on()
            self.bt.ctl_visible_off()
            if i % 20 == 0:
                print ("Finished %d cycles successfuly." % i)

##
# @}
# @}
##
