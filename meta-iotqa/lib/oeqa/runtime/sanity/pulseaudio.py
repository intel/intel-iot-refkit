from oeqa.oetest import oeRuntimeTest
from oeqa.utils.decorators import tag

class PulseaudioTest(oeRuntimeTest):

    '''Check pulseaudio existence'''
    def test_pulseaudio_exists(self):

        (status, output) = self.target.run('ls /usr/bin/pulseaudio')

        self.assertEqual(output, "/usr/bin/pulseaudio", msg="Error messages: pulseaudio not found")
