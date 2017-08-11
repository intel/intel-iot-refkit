import os
from oeqa.oetest import oeRuntimeTest

class SanityTestOpengl(oeRuntimeTest):
    """
    @class SanityTestOpengl
    """

    apprt_test_opengl_dots = 'apprt_test_opengl_dots.py'
    apprt_test_opengl_triangle = 'apprt_test_opengl_triangle.py'
    apprt_test_opengl_3dsphere = 'apprt_test_opengl_3dsphere.py'

    apprt_test_opengl_dots_target = '/tmp/%s' % apprt_test_opengl_dots
    apprt_test_opengl_triangle_target = '/tmp/%s' % apprt_test_opengl_triangle
    apprt_test_opengl_3dsphere_target = '/tmp/%s' % apprt_test_opengl_3dsphere


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
                SanityTestOpengl.apprt_test_opengl_dots),
            SanityTestOpengl.apprt_test_opengl_dots_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                SanityTestOpengl.apprt_test_opengl_triangle),
            SanityTestOpengl.apprt_test_opengl_triangle_target)
        self.target.copy_to(
            os.path.join(
                os.path.dirname(__file__),
                'files',
                SanityTestOpengl.apprt_test_opengl_3dsphere),
            SanityTestOpengl.apprt_test_opengl_3dsphere_target)



    def test_opengl_dots(self):
        '''
        Test if creates a white window with three black dots.
        @fn test_opengl_dots
        @param self
        @return
        '''
        (status, output) = self.target.run('python %s' % SanityTestOpengl.apprt_test_opengl_dots_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)



    def test_opengl_triangle(self):
        '''
        Test if creates Sierpinski's triangle.
        @fn test_opengl_triangle
        @param self
        @return
        '''
        (status, output) = self.target.run('python %s' % SanityTestOpengl.apprt_test_opengl_triangle_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)



    def test_opengl_3dsphere(self):
        '''
        Test if creates 3D Spherical image.
        @fn test_opengl_3dsphere
        @param self
        @return
        '''
        (status, output) = self.target.run('python %s' % SanityTestOpengl.apprt_test_opengl_3dsphere_target)
        self.assertEqual(status, 0, msg="Error messages: %s" % output)


    def tearDown(self):
        '''
        Clean work: remove all the files copied to the target device.
        @fn tearDown
        @param self
        @return
        '''
        self.target.run(
            'rm -f %s %s %s %s' %
            (SanityTestOpengl.apprt_test_opengl_dots_target,
             SanityTestOpengl.apprt_test_opengl_triangle_target,
             SanityTestOpengl.apprt_test_opengl_3dsphere_target))

