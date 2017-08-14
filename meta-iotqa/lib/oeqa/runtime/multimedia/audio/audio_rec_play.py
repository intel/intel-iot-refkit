import time
from oeqa.oetest import oeRuntimeTest


class AlsaTest(oeRuntimeTest):
    def test_rec_play(self):
        # Recording audio
        (status, output) = self.target.run("arecord -d 5 -f cd -D plughw:1,0 /home/rec.wav")
	 time.sleep(3)
        self.assertEqual(status, 0, msg="Error Not recorded: %s" % output)
        (status, output) = self.target.run("ls /home/ |grep 'rec.wav'")
        self.assertEqual(status, 0, msg="Error File not present: %s" % output)
        # Playing audio
        (status, output) = self.target.run("aplay -D plughw:1,0 /home/rec.wav &")
        self.assertEqual(status, 0, msg="Error Not playing: %s" % output)
        # Audio running states checking
        (status, output) = self.target.run("cat /proc/asound/card0/pcm0p/sub0/status |grep 'state: RUNNING'")
        self.assertEqual(status, 0, msg="Error Audio not running : %s" % output)
