import time
from oeqa.oetest import oeRuntimeTest


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

    def test_rec_play(self):
        # Start pulseaudio daemon
        (status, output) = self.target.run("pulseaudio --start")
        self.assertEqual(status, 0, msg="Error pulseaudio not started: %s" % output)
        # Recording audio
        (status, output) = self.target.run("parecord -r /tmp/rec.wav &")
        time.sleep(10)
        self.assertEqual(status, 0, msg="Error not recorded: %s" % output)
        # Stop pulseaudio daemon
        (status, output) = self.target.run("killall -9 parecord")
        self.assertEqual(status, 0, msg="Error pulse record not stop: %s" % output)
        # Playing audio
        self.target.run("paplay /tmp/rec.wav &")
        time.sleep(3)
        (status, output) = self.target.run("pactl list | grep RUNNING")
        if status == 1:
            # audio not played.
            self.assertEqual(output, "Not playing recorded audio", msg="Error messages: %s" % output)
        else:
            # RUNNING state checking
            self.assertEqual(status, 0, msg="Error in playing: %s" % output)
