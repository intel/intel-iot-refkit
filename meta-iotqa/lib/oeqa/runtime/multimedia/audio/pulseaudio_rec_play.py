import time
from oeqa.oetest import oeRuntimeTest


class PulseaudioTest(oeRuntimeTest):
    def test_rec_play(self):
        # Start pulseaudio daemon
        (status, output) = self.target.run("pulseaudio -D")
        self.assertEqual(status, 0, msg="Error pulseaudio not started: %s" % output)
        # Recording audio
        (status, output) = self.target.run("parecord -r /tmp/rec.wav &")
        time.sleep(3)
        self.assertEqual(status, 0, msg="Error not recorded: %s" % output)
        # Stop pulseaudio daemon
        (status, output) = self.target.run("pulseaudio -k")
        self.assertEqual(status, 0, msg="Error pulseaudio not stop: %s" % output)
        # start pulseaudio daemon
        (status, output) = self.target.run("pulseaudio -D")
        self.assertEqual(status, 0, msg="Error pulseaudio not started: %s" % output)
        # Checking recorded file present
        (status, output) = self.target.run("ls /tmp/ |grep 'rec.wav'")
        self.assertEqual(status, 0, msg="Error file not found: %s" % output)
        # Playing audio
        (status, output) = self.target.run("paplay /tmp/rec.wav &")
        self.assertEqual(status, 0, msg="Error not played: %s" % output)
        # Audio running states checking
        (status, output) = self.target.run("cat /proc/asound/card1/pcm3p/sub0/status |grep 'state: RUNNING'")
        self.assertEqual(status, 0, msg="Error not running: %s" % output)
