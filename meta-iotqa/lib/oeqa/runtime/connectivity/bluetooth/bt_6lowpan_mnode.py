from oeqa.runtime.connectivity.bluetooth import bluetooth
from oeqa.oetest import oeRuntimeTest
from oeqa.utils.helper import shell_cmd_timeout


class CommBT6LowPanMNode(oeRuntimeTest):
    def setUp(self):
        self.bt1 = bluetooth.BTFunction(self.targets[0])
        self.bt2 = bluetooth.BTFunction(self.targets[1])

        self.bt1.target_hciconfig_init()
        self.bt2.target_hciconfig_init()

    def tearDown(self):
        self.bt1.disable_6lowpan_ble()
        self.bt2.disable_6lowpan_ble()

    def test_bt_connect_6lowpan(self):
        """
        Setup two devices with BLE
        """
        self.bt1.connect_6lowpan_ble(self.bt2)

    def test_bt_6lowpan_ping6_out(self):
        """
        Setup two devices with BLE, and ping each other
        """
        self.bt1.connect_6lowpan_ble(self.bt2)
        # first device to ping second device
        self.bt1.bt0_ping6_check(self.bt2.get_bt0_ip())

    def test_bt_6lowpan_be_pinged(self):
        """
        Setup two devices with BLE, and ping each other
        """
        self.bt1.connect_6lowpan_ble(self.bt2)
        # first device to ping second device
        self.bt2.bt0_ping6_check(self.bt1.get_bt0_ip())

    def test_bt_6lowpan_ssh_to(self):
        """
        Setup two devices with BLE, and ssh to remote
        """
        self.bt1.connect_6lowpan_ble(self.bt2)
        # first device to ping second device
        self.bt1.bt0_ssh_check(self.bt2.get_bt0_ip())

    def test_bt_6lowpan_be_ssh(self):
        """
        Setup two devices with BLE, and remote ssh to self
        """
        self.bt1.connect_6lowpan_ble(self.bt2)
        # first device to ping second device
        self.bt2.bt0_ssh_check(self.bt1.get_bt0_ip())

##
# @}
# @}
##
