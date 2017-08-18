import time
from oeqa.oetest import oeRuntimeTest


class PulseaudioTest(oeRuntimeTest):
    def test_rec_play(self):
        # Start pulseaudio daemon
        (status, output) = self.target.run("pulseaudio -D")
        self.assertEqual(status, 0, msg="Error pulseaudio not started: %s" % output)
        # Recording audio
        (status, output) = self.target.run("parecord -r /tmp/rec.wav&")
        time.sleep(10)
        self.assertEqual(status, 0, msg="Error not recorded: %s" % output)
        # Stop pulseaudio daemon
        (status, output) = self.target.run("killall -9 parecord")
        self.assertEqual(status, 0, msg="Error pulseaudio not stop: %s" % output)
        # Playing audio
        (status, output) = self.target.run("paplay /tmp/rec.wav&")
        self.assertEqual(status, 0, msg="Error not played: %s" % output)
        # RUNNING state checking
        time.sleep(3)
        (status, output) = self.target.run("pactl list | grep RUNNING")
        self.assertEqual(status, 0, msg="Error not running: %s" % output)
