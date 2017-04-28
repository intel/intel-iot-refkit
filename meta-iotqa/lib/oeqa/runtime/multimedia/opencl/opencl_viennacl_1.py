from oeqa.oetest import oeRuntimeTest

class OpenCLViennaCL1Test(oeRuntimeTest):
    def test_opencl_viennacl_1(self):
        # Run an example test from viennacl-examples
        (status, output) = self.target.run('dense_blas-bench-opencl')
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
