import time
import subprocess
from oeqa.oetest import oeRuntimeTest


class SanityTestFlatpakCommandline(oeRuntimeTest):
    """
    @class SanityTestFlatpak
    """

    def test_version(self):
        '''
        Test the version of flatpak.
        @fn test_version
        '''
        # ************Flatpak Version************
        (status, output) = self.target.run("flatpak --version")
        self.assertEqual(status, 0, msg="flatpak version command failed: %s " % output)


    def test_list(self):
        '''
        Test to list down all flatpak app.
        @fn test_list
        '''
        # ************Flatpak List************
        (status, output) = self.target.run("flatpak list")
        self.assertEqual(status, 0, msg="flatpak list command failed: %s " % output)


    def test_run(self):
        '''
        Test to run an application using flatpak.
        @fn test_run
        @param self
        @return
        '''
        # ************Flatpak Run************
        p = subprocess.Popen('flatpak run org.example.BasePlatform/x86_64/refkit.0', shell=True, stdout=subprocess.PIPE)
        time.sleep(2)
        p.terminate()
