import os
from oeqa.oetest import oeRuntimeTest

class OpenCVTest(oeRuntimeTest):

    cv_read_image = 'cv_read_image.py'
    cv_capture_video = 'cv_capture_video.py'
    cv_process_image = 'cv_process_image.py'
    cv_detect_shape = 'cv_detect_shape.py'
    '''
    Images from https://github.com/opencv/opencv/tree/master/samples/data
    '''
    cv_image_src = 'pic5.png'
    
    cv_read_image_target = '/tmp/%s' % cv_read_image
    cv_capture_video_target = '/tmp/%s' % cv_capture_video
    cv_process_image_target = '/tmp/%s' % cv_process_image
    cv_detect_shape_target = '/tmp/%s' % cv_detect_shape
    cv_image_src_target = '/tmp/%s' % cv_image_src

    def setUp(self):
        '''
        Copy all necessary files for test to the target device.
        @fn setUp
        @param self
        @return
        '''
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                OpenCVTest.cv_read_image),
            OpenCVTest.cv_read_image_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                OpenCVTest.cv_capture_video),
            OpenCVTest.cv_capture_video_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                OpenCVTest.cv_process_image),
            OpenCVTest.cv_process_image_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                OpenCVTest.cv_detect_shape),
            OpenCVTest.cv_detect_shape_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                OpenCVTest.cv_image_src),
            OpenCVTest.cv_image_src_target)

    def test_cv_read_image(self):
        (status, output) = self.target.run('python %s' % OpenCVTest.cv_read_image_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
	
    def test_cv_capture_video(self):
        (status, output) = self.target.run('python %s 0' % OpenCVTest.cv_capture_video_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        
    def test_cv_process_image(self):
        (status, output) = self.target.run('python %s' % OpenCVTest.cv_process_image_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
    
    def test_cv_detect_shape(self):
        (status, output) = self.target.run('python %s' % OpenCVTest.cv_detect_shape_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
		
    def tearDown(self):
        '''
        Clean work: remove all the files copied to the target device.
        @fn tearDown
        @param self
        @return
        '''
        self.target.run(
            'rm -f %s %s %s %s %s' %
            (OpenCVTest.cv_read_image_target,
             OpenCVTest.cv_capture_video_target,
             OpenCVTest.cv_process_image_target,
             OpenCVTest.cv_detect_shape_target,
             OpenCVTest.cv_image_src_target))
