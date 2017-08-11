from oeqa.oetest import oeRuntimeTest


class AlsaTest(oeRuntimeTest):
    def test_rec_play(self):
        # Recording audio
        (status, output) = self.target.run("arecord -d 1 -f cd -D plughw:0,0 /home/rec.wav")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        (status, output) = self.target.run("ls /home/ |grep 'rec.wav'")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        # Playing audio
        (status, output) = self.target.run("aplay -D plughw:0,0 /home/rec.wav &")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
        # Audio running states checking
        (status, output) = self.target.run("cat /proc/asound/card0/pcm0p/sub0/status |grep 'state: RUNNING'")
        self.assertEqual(status, 0, msg="Error messages: %s" % output)
