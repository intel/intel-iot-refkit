'''
this test suit tests functioning of mraa-gpio commands
mraa-gpio list
mraa-gpio set <pin> <value>
mraa-gpio get <pin>

'''

from oeqa.oetest import oeRuntimeTest
import unittest
import subprocess
import os
from time import sleep

class MraaGpioTest(oeRuntimeTest):
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

        if not os.path.exists("/sys/class/gpio/gpio20"):
            subprocess.check_output("echo 20 > /sys/class/gpio/export", shell=True)

    def host_gpio_read(self):
        cmd = "cat /sys/class/gpio/gpio20/value".split()
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        return int(output)

    def host_gpio_write(self, value):
        cmd = 'echo %s > /sys/class/gpio/gpio20/value' % value
        subprocess.check_output(cmd, shell=True)

    def dut_mraa_gpio_get_value(self):
        status, output = self.target.run("mraa-gpio get " + self.pin)
        output = str(output)
        self.assertEqual(status, 0, msg="mraa-gpio get command failed: %s " % output)
        _, string2 = output.split("=")
        return int(string2)

    def test_gpio_cmd_set(self):
        '''
        Test a GPIO pin on and off and check the pin output with
        BeagleBone. DUT GPIO Pin is shorted with BeagleBone to check value for mraa-gpio set
        it is shorted to gpio pin numeber 20 in BeagleBone
        '''

        subprocess.check_output("echo in > /sys/class/gpio/gpio20/direction", shell=True)
        status, output = self.target.run("mraa-gpio set " + self.pin + " 1")
        sleep(1)
        gpio = self.host_gpio_read()
        self.assertEqual(gpio, 1, msg="GPIO pin output is not 1, " +
                                      "mraa output:\n" + output)

        status, output = self.target.run("mraa-gpio set " + self.pin + " 0")
        sleep(1)
        gpio = self.host_gpio_read()
        self.assertEqual(gpio, 0, msg="GPIO pin output is not 0, " +
                                      "mraa output:\n" + output)

        status, output = self.target.run("mraa-gpio set " + self.pin + " 1")
        sleep(1)
        gpio = self.host_gpio_read()
        self.assertEqual(gpio, 1, msg="GPIO pin output is not 1, " +
                                      "mraa output:\n" + output)

    def test_gpio_cmd_list(self):

        (status, output) = self.target.run("mraa-gpio list")
        self.assertEqual(status, 0, msg="mraa-gpio list command failed: %s " % output)

    def test_gpio_cmd_get(self):

        subprocess.check_output("echo out > /sys/class/gpio/gpio20/direction", shell=True)
        self.host_gpio_write(0)
        sleep(1)
        output = self.dut_mraa_gpio_get_value()
        self.assertEqual(output, 0, msg="GPIO value is not 0 ")

        self.host_gpio_write(1)
        sleep(1)
        output = self.dut_mraa_gpio_get_value()
        self.assertEqual(output, 1, msg="GPIO value is not 1 ")

        self.host_gpio_write(0)
        sleep(1)
        output = self.dut_mraa_gpio_get_value()
        self.assertEqual(output, 0, msg="GPIO value is not 0 ")
        subprocess.check_output("echo in > /sys/class/gpio/gpio20/direction", shell=True)

