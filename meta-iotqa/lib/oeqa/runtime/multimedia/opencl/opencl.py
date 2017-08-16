from oeqa.oetest import oeRuntimeTest

class OpenCLTest(oeRuntimeTest):
    def test_opencl_app_can_execute(self):
        (status, output) = self.target.run('/usr/bin/opencl-bench-opencl')
        self.assertEqual(status, 0, msg="OpenCL error messages: %s" % output)

