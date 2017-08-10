'''
this test suit sets value from BeagleBone and receive it at DUT

'''

from oeqa.oetest import oeRuntimeTest
import unittest
import subprocess
import os
import re
from time import sleep


class MraaGpioGetTest(oeRuntimeTest):
    '''
    These tests require to use BeagleBone as testing host
    '''
    pin = ""

    def setUp(self):

        (status, output) = self.target.run("mraa-gpio version")
        self.assertEqual(status, 0, msg="mraa-gpio version command failed: %s " % output)
        output = output.lower()
        if any(x in output for x in ("broxton", "tuchuck", "joule")):
            self.pin = "51"
        elif "minnowboard" in output:
            self.pin = "25"
        else:
            raise unittest.SkipTest(output)

        output = os.path.exists("/sys/class/gpio/gpio20")
        output = str(output)
        output = output.lower()
        if "false" in output:
            subprocess.check_output("echo 20 > /sys/class/gpio/export", shell=True)

        subprocess.check_output("echo out > /sys/class/gpio/gpio20/direction", shell=True)

    def mraa_gpio_get_value(self):
        status, output = self.target.run("mraa-gpio get " + self.pin)
        output = str(output)
        string1, string2 = output.split("=")
        string2 = int(re.search(r'\d+', string2).group())
        return int(string2)

    def test_mraa_gpio_get_value(self):

        subprocess.check_output("echo 0 > /sys/class/gpio/gpio20/value", shell=True)
        sleep(1)
        output = self.mraa_gpio_get_value()
        self.assertEqual(output, 0, msg="GPIO value is not 0 ")

        subprocess.check_output("echo 1 > /sys/class/gpio/gpio20/value", shell=True)
        sleep(1)
        output = self.mraa_gpio_get_value()
        self.assertEqual(output, 0, msg="GPIO value is not 1 ")

        subprocess.check_output("echo 0 > /sys/class/gpio/gpio20/value", shell=True)
        sleep(1)
        output = self.mraa_gpio_get_value()
        self.assertEqual(output, 0, msg="GPIO value is not 0 ")
        subprocess.check_output("echo 20 > /sys/class/gpio/unexport", shell=True)
