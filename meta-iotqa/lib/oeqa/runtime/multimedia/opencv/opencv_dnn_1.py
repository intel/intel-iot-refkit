from oeqa.oetest import oeRuntimeTest

class OpenCVDNN1Test(oeRuntimeTest):
    def test_opencv_dnn_1(self):
        # Classify an image using opencv-dnn
        (status, output) = self.target.run('dnn-test.py /usr/share/Caffe/data/deploy.prototxt /usr/share/Caffe/models/bvlc_reference_caffenet/bvlc_reference_caffenet.caffemodel /usr/share/Caffe/data/dog.jpg')
        # The dog must be identified as Saluki, gazelle hound. It's
        # index 176.
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        lines = output.split("\n")
        self.assertEqual(lines[-1], "176", msg="Misclassified image(%s): %s " % (lines[-1], output))
