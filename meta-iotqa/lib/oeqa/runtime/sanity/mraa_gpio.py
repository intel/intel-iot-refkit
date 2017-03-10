from oeqa.oetest import oeRuntimeTest
import unittest
import subprocess
from time import sleep

class MraaGpioTest(oeRuntimeTest):
    '''
    These tests require to use BeagleBone as testing host
    '''
    pin = ""
    def setUp(self):
        (status, output)= self.target.run("mraa-gpio version")
        output = output.lower()
        if any(x in output for x in ("broxton", "tuchuck", "joule")):
            self.pin = "51"
        elif "minnowboard" in output:
            self.pin = "25"
        else:
            raise unittest.SkipTest(output)

    def test_gpio(self):
        '''
        Test a GPIO pin on and off and check the pin output with
        BeagleBone
        '''
        def check_gpio_output():
            cmd = "cat /sys/class/gpio/gpio20/value".split()
            output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
            return int(output)

        status, output = self.target.run("mraa-gpio set " + self.pin + " 0")
        sleep(1)
        gpio = check_gpio_output()
        self.assertEqual(gpio, 0, msg="GPIO pin output is not 0, " +
                                      "mraa output:\n" + output)

        status, output = self.target.run("mraa-gpio set " + self.pin + " 1")
        sleep(1)
        gpio = check_gpio_output()
        self.assertEqual(gpio, 1, msg="GPIO pin output is not 1, " +
                                      "mraa output:\n" + output)

        status, output = self.target.run("mraa-gpio set " + self.pin + " 0")
        sleep(1)
        gpio = check_gpio_output()
        self.assertEqual(gpio, 0, msg="GPIO pin output is not 0, " +
                                      "mraa output:\n" + output)
