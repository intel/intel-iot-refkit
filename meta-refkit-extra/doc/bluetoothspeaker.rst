Bluetooth Speaker
#################

This is a demo to convert Intel 570x development board into stand
alone bluetooth speaker. Main application is a python file
``btspeaker.py`` and it is run under a Linux user called
``btspeaker``. The demo uses fairly "stock" components like
``PulseAudio``, ``BlueZ`` and ``ConnMan``. These are included in the
IoT Reference OS Kit's gateway profile. The 570x doesn't have audio
codec (hence no audio jack connector or speaker) so if you want to
hear sound you need to connect something either to HDMI (like display
with speakers or home theater amplifier) or to USB (like USB sound
card or headset).

``btspeaker.py`` is started in boot with ``systemd`` service file and
``PulseAudio`` is started at the same time by playing a "startup
tune". There's also special ``PulseAudio`` ``client.conf`` installed
to btspeaker's home directory to make ``PulseAudio`` not exit when
idling (this is the default ``PulseAudio`` behavior). This is done
because we want to listen and wake up for ``BlueZ`` audio connection
events. With these events ``PulseAudio`` setups the A2DP audio
path. Also in the beginning of the execution ``ConnMan`` is used
through ``DBus`` to unblock the bluetooth radio.

How to build
============

1) Add "require conf/distro/include/refkit-extra.conf" to local.conf

2) Uncomment the following line in refkit-extra.conf:

   require conf/distro/include/refkit-extra-btspeaker.conf

3) Build

   bitbake refkit-image-gateway

   or

   docker/local-build.sh refkit-image-gateway

570x Buttons and Leds
=====================

The 570x's general purpose button and leds are taken into use by
defining special ACPI tables, which are injected to be read before
initramfs. The button is visible as an input device and the leds are
under sysfs. Because of this the user btspeaker is added to groups
input and leds. Leds is not a "standard" linux distro group but it is
created for this application. Demo includes a special udev rule to
change the leds under sysfs to ``leds`` group so they can be operated
by a user in that group (and not only root).

For the ACPI table injection to work the demo needs to include 4.10
Kernel. The ACPI tables and bitbake recipe invocations are
gotten/modified from Mika Westerberg's meta-acpi layer in Github.

Functionality
=============

Application is a always listening for GP_BTN button press. If you
press the button the device will go to "pairing" mode and waits for
the first device to connect. Application will also clean up all
previous connections at this point. The led should also start to blink
at this point. If nothing is connected under 1 minute the device will
exit pairing mode and wait for another button press. When pressing the
button also a "pairing" sound should be played.

After you have pressed the button the device should be visible in the
device you want to pair (like your phone). Just pair your phone and
the device should accept the pairing automatically. After pairing you
might need to connect for the media playback (This is phone UI
dependent feature). After succesful connection a "success" sound is
played. You should see a succesful connection in your phone and after
that you can just start the playback from your favourite service or
media files.
