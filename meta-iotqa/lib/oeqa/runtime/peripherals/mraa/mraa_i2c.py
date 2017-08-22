from oeqa.oetest import oeRuntimeTest


class MraaI2cTest(oeRuntimeTest):
    # checking i2c version
    def test_mraa_i2c_version(self):
        (status, output) = self.target.run("mraa-i2c version")
        self.assertEqual(status, 0, msg="Error i2c version : %s" % output)

    # checking i2c list present
    def test_mraa_i2c_list(self):
        (status, output) = self.target.run("mraa-i2c list")
        self.assertEqual(status, 0, msg="Error i2c list: %s" % output)

    # Checking slave detect bus
    def test_mraa_i2c_detectbus(self):
        (status, output) = self.target.run("mraa-i2c detect bus")
        self.assertEqual(status, 0, msg="Error i2c detect bus: %s" % output)
