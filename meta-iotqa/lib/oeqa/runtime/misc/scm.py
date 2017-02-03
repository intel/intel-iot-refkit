from oeqa.oetest import oeRuntimeTest
from oeqa.utils.decorators import tag

@tag(TestType="FVT", FeatureID="IOTOS-722")

class ScmTest(oeRuntimeTest):
    """ Misc/scm testing
    @class ScmTest
    """
    def test_multiple_partition_image(self):
        """ check the image has multiple partition
        @fn test_multiple_partition_image
        @param self
        @return
        """
        (status,output) = self.target.run("cat /proc/partitions | grep -v major | grep -v ^$ | grep -v ram |wc -l")
        ##
        # TESTPOINT: check there are more than 1 partitions
        #
        self.assertEqual(status, 0, msg="Error message: %s" % output)
        self.assertTrue((int(output) > 1), msg="Error message: the partition is %s" % output)
