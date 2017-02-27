import os
from oeqa.runtime.wifi import wifi
try:
    import ConfigParser
except:
    import configparser as ConfigParser
from oeqa.oetest import oeRuntimeTest

ssid_config = ConfigParser.ConfigParser()
config_path = os.path.join(os.path.dirname(__file__), "files/config.ini")
ssid_config.readfp(open(config_path))

class CommWiFiConect(oeRuntimeTest):

    def setUp(self):
        '''
        Initialize wifi class
        '''
        self.wifi = wifi.WiFiFunction(self.target)

    def tearDown(self):
        '''
        Disable wifi after testing
        '''
        self.wifi.disable_wifi()

    def test_wifi_connect(self):
        '''
        Use connmanctl to connect to wifi. The AP that will be tried to connect
        to is determined by './files/config.ini'.
        '''
        ap_type = ssid_config.get("Connect","type")
        ssid = ssid_config.get("Connect","ssid")
        pwd = ssid_config.get("Connect","passwd")

        self.wifi.execute_connection(ap_type, ssid, pwd)
