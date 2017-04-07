from oeqa.runtime.connectivity.bluetooth import bluetooth
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import shell_cmd_timeout


class CommBT6LowPAN(oeRuntimeTest):
    def setUp(self):
        self.bt = bluetooth.BTFunction(self.target)
        self.bt.target_hciconfig_init()

    def test_bt_insert_6lowpan_module(self):
        """
        Insert 6lowpan module
        """
        self.bt.insert_6lowpan_module()

    def test_bt_enable_6lowpan_ble(self):
        """
        Enable 6lowpan over BLE
        """
        self.bt.enable_6lowpan_ble()

##
# @}
# @}
##
