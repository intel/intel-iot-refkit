import os
import time
import subprocess
from oeqa.runtime.connectivity.bluetooth import bluetooth
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import shell_cmd_timeout
from oeqa.utils.helper import get_files_dir


class CommBTTest(oeRuntimeTest):
    def setUp(self):
        self.bt = bluetooth.BTFunction(self.target)
        self.bt.target_hciconfig_init()

    def test_bt_power_on(self):
        """
        Enable bluetooth device
        """
        self.target.run('hciconfig hci0 down')
        self.bt.ctl_power_on()

    def test_bt_power_off(self):
        """
        Disable bluetooth device
        """
        self.target.run('hciconfig hci0 up')
        self.bt.ctl_power_off()

    def test_bt_visible_on(self):
        """
        Enable visibility
        """
        self.target.run('hciconfig hci0 noscan')
        self.bt.ctl_visible_on()

    def test_bt_visible_off(self):
        """
        Disable visibility
        """
        self.target.run('hciconfig hci0 piscan')
        self.bt.ctl_visible_off()

    def test_bt_change_name(self):
        """
        Change BT device name
        """
        new_name = "iot-bt-test"
        self.target.run('hciconfig hci0 name %s' % new_name)
        name = self.bt.get_name()
        if type(name) is bytes:
            name = name.decode('ascii')
        if name == new_name:
            pass
        else:
            self.assertEqual(1, 0, msg="Bluetooth set name fails. Current name is: %s" % name)

##
# @}
# @}
##
