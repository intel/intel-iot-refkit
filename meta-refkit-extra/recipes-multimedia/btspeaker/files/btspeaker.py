#!/usr/bin/python3
import os
import sys
import dbus
import dbus.service
import dbus.mainloop.glib
import time
import threading
import wave
import alsaaudio
import evdev
from evdev import ecodes
from select import select
try:
  from gi.repository import GObject
except ImportError:
  import gobject as GObject

# Class to be used as bluetooth agent for pairing
class my_bt_agent(dbus.service.Object):

    @dbus.service.method('org.bluez.Agent1', in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        global mainloop
        mainloop.quit()
        return

# Class for playing wav files
class play_sound (threading.Thread):
    def __init__(self, threadID, name, soundfile):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = name
        self.soundfile = soundfile
    def run(self):
        # open audio file and device
        audio_file = wave.open(self.soundfile, 'rb')
        audio_device = alsaaudio.PCM(alsaaudio.PCM_PLAYBACK, alsaaudio.PCM_NORMAL, 'default')

        # we are hard coding the audio format!
        audio_device.setchannels(2)
        audio_device.setrate(44100)
        audio_device.setformat(alsaaudio.PCM_FORMAT_S16_LE)
        audio_device.setperiodsize(980)

        # play the audio
        audio_data = audio_file.readframes(980)
        while audio_data:
          audio_device.write(audio_data)
          audio_data = audio_file.readframes(980)

        audio_file.close()

# Class for blinking the leds
class blink_led (threading.Thread):
    def __init__(self, threadID, name):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = name
        self.lede_on = False

    def set_led(self, onoff):
        value = open("/sys/class/leds/led-3/brightness","w")
        if onoff == True:
            value.write(str(1))
            self.lede_on = True
        else:
            value.write(str(0))
            self.lede_on = False
        value.close()

    def run(self):
        global pairing
        global mainloop
        sleep_time = 0.2
        sleep_counter = 0
        max_pair_time = 60

        while 1:
            if (pairing == True):
                if self.lede_on == False:
                    self.set_led(True)
                else:
                    self.set_led(False)

                time.sleep(sleep_time)
                sleep_counter = sleep_counter + sleep_time

                if sleep_counter >= max_pair_time:
                    pairing = False
                    mainloop.quit()
                    self.set_led(False)
                    return
            else:
                self.set_led(False)
                return

# Class for capturing the button events
class button_cb(threading.Thread):
    def __init__(self, threadID, name):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = name
    def run(self):
        global pairing
        devices = [evdev.InputDevice(file_name) for file_name in evdev.list_devices()]
        for dev in devices:
          if 'PRP0001' in dev.name:
            device = evdev.InputDevice(dev.fn)
        while 1:
            r,w,x = select([device.fd], [], [], 0.1)
            if r:
                for event in device.read():
                    if event.code == ecodes.KEY_HOME and event.value == 1:
                        if pairing == False:
                            pairing = True
                            buttonwait.set()

# Following function is heavily inspired by BlueZ tests
def remove_paired_bt_device():
    bus = dbus.SystemBus()
    om = dbus.Interface(bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
    obj = om.GetManagedObjects()
    bt_adapter_path = "/org/bluez/hci0"
    bt_device = None
    bt_adapter = None

    for path, interf in obj.iteritems():
        if "org.bluez.Device1" in interf:
            properties = interf["org.bluez.Device1"]
            if properties["Adapter"] == bt_adapter_path:
                bt_device_inter = interf.get("org.bluez.Device1")
                if bt_device_inter["Address"] == properties["Address"]:
                    obj2 = bus.get_object("org.bluez", path)
                    bt_device = dbus.Interface(obj2, "org.bluez.Device1")
                    bt_adapter = dbus.Interface(obj2, "org.bluez.Adapter1")
                    print("found device object")
                    break;

    for path, interf in obj.iteritems():
        adapter_inter = interf.get("org.bluez.Adapter1")
        if adapter_inter is not None:
            obj2 = bus.get_object("org.bluez", path)
            bt_adapter = dbus.Interface(obj2, "org.bluez.Adapter1")

    if bt_device is not None:
        for attr in dir(bt_device):
          print "bt_device.%s = %s" % (attr, getattr(bt_device, attr))
        bt_device.Disconnect()
        path = bt_device.object_path
        if bt_adapter is not None:
          bt_adapter.RemoveDevice(path)

# This is the main pairing functions called from main thread
def do_pair():
    global pairing
    global mainloop

    bus = dbus.SystemBus()

    #remove connected and paired device from bluez
    remove_paired_bt_device()

    # we are using our own agent to bypass authorization and get callback for connected state
    path = "/test/agent"
    agent = my_bt_agent(bus, path)
    obj = bus.get_object('org.bluez', "/org/bluez");
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(path, 'NoInputNoOutput')
    manager.RequestDefaultAgent(path)

    adapter1_path = "/org/bluez/hci0"
    adapter1 = dbus.Interface(bus.get_object("org.bluez", adapter1_path), "org.freedesktop.DBus.Properties")

    adapter1.Set("org.bluez.Adapter1", "Powered", dbus.Boolean(1))
    adapter1.Set("org.bluez.Adapter1", "Pairable", dbus.Boolean(1))
    adapter1.Set("org.bluez.Adapter1", "Discoverable", dbus.Boolean(1))

    # let's wait for paired callback from bluez or timeout from led blink
    mainloop.run()

    pairing = False

    manager.UnregisterAgent(path)
    agent.remove_from_connection()

mainloop = 0;
buttonwait = threading.Event()
pairing = False
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

if __name__ == '__main__':

    bus = dbus.SystemBus()
    GObject.threads_init()
    mainloop = GObject.MainLoop()

    # let's unblock bt radio with connman
    conn = bus.get_object('net.connman', '/net/connman/technology/bluetooth')
    iface = dbus.Interface(conn, dbus_interface='net.connman.Technology')
    props = iface.GetProperties()
    if props["Powered"] == 0:
        iface.SetProperty("Powered", dbus.Boolean(1))

    # play start sound so we get pulseaudio up and running
    sound = play_sound(4, "play_start", "/home/btspeaker/btstartup.wav")
    sound.start()

    # let's start listening for button events
    button = button_cb(4, "button")
    button.daemon = True
    button.start();

    # goto button wait and bt pairing loop
    while 1:
        buttonwait.wait()
        sound = play_sound(2, "play_start", "/home/btspeaker/btpairing.wav")
        sound.daemon = True
        sound.start()
        led = blink_led(1, "led")
        led.daemon = True
        led.start()
        do_pair()
        sound = play_sound(3, "play_paired", "/home/btspeaker/btsuccess.wav")
        sound.daemon = True
        sound.start()
        buttonwait.clear()
