import subprocess
import time

'''
Run the flatpak application and then terminate the process.
'''

def flatpak_cmd_runapp():
    p = subprocess.Popen('flatpak run org.example.BasePlatform/x86_64/refkit.0', shell=True, stdout=subprocess.PIPE)
    time.sleep(2)
    p.terminate()

if __name__ == '__main__':flatpak_cmd_runapp()
