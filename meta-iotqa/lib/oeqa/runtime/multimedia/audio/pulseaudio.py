from oeqa.oetest import oeRuntimeTest
from oeqa.utils.decorators import tag

class PulseaudioTest(oeRuntimeTest):

    '''Check pulseaudio existence'''
    def test_pulseaudio_exists(self):

        (status, output) = self.target.run('ls /usr/bin/pulseaudio')

        self.assertEqual(output, "/usr/bin/pulseaudio", msg="Error messages: pulseaudio not found")

    def test_modules_loaded(self):
        '''
        Check that necessary modules for Pulseaudio are loaded
        '''
        self.target.run("useradd testuser")
        self.target.run("usermod -a -G pulse,audio testuser")
        (status, xdg_runtime_dir) = self.target.run("env | grep XDG_RUNTIME_DIR")
        (status, output) = self.target.run("unset XDG_RUNTIME_DIR; su testuser -c \"pactl list\"")

        self.assertIn("module-bluetooth-policy", output,
            msg=("module-bluetooth-policy not found, pactl output:\n" + output))

        self.assertIn("module-bluetooth-discover", output,
            msg=("module-bluetooth-discover not found, pactl output:\n" + output))

        self.assertIn("module-bluez5-discover", output,
            msg=("module-bluez5-discover not found, pactl output:\n" + output))

        self.target.run("su testuser -c \"pulseaudio --kill\"")
        self.target.run("userdel testuser")
        self.target.run("rm -rf /home/testuser")
        self.target.run("su testuser -c \"pulseaudio --start\"")
        self.target.run("XDG_RUNTIME_DIR=" + xdg_runtime_dir)
