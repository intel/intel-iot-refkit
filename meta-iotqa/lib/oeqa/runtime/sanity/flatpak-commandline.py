import os
from oeqa.oetest import oeRuntimeTest


class SanityTestFlatpakCommandline(oeRuntimeTest):
    """
    @class SanityTestFlatpak
    """

    flatpak_cmd_runapp = 'flatpak_cmd_runapp.py'

    flatpak_cmd_runapp_target = '/tmp/%s' % flatpak_cmd_runapp

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
                SanityTestFlatpakCommandline.flatpak_cmd_runapp),
            SanityTestFlatpakCommandline.flatpak_cmd_runapp_target)

    def test_flatpak_cmd_version(self):
        '''
        Test the version of flatpak.
        @fn test_version
        '''
        # ************Flatpak Version************
        (status, output) = self.target.run("flatpak --version")
        self.assertEqual(status, 0, msg="flatpak version command failed: %s " % output)

    def test_flatpak_cmd_list(self):
        '''
        Test to list down all flatpak app.
        @fn test_list
        '''
        # ************Flatpak List************
        (status, output) = self.target.run("flatpak list")
        self.assertEqual(status, 0, msg="flatpak list command failed: %s " % output)

    def test_flatpak_cmd_run(self):
        '''
        Test to run an application using flatpak.
        @fn test_run
        @param self
        @return
        '''
        # ************Flatpak Run************
        (status, output) = self.target.run('python %s' % SanityTestFlatpakCommandline.flatpak_cmd_runapp_target)
        self.assertEqual(status, 0, msg="flatpak run command failed: %s " % output)

    def tearDown(self):
        '''
        Clean work: remove all the files copied to the target device.
        @fn tearDown
        @param self
        @return
        '''
        self.target.run(
            'rm -f %s' %
            (SanityTestFlatpakCommandline.flatpak_cmd_runapp_target))
