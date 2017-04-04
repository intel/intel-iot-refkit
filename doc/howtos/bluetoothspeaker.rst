Bluetooth Speaker
#################

The instructions below show you how to build a bluetooth speaker using
an Intel 570x development board running intel-iot-refkit image. For
configuring the bluetooth speaker setup you should use the "gateway"
image and prepare couple of configuration files. This configuration
has been tested to work with Intel 570x development board which has
bluetooth radio chip integrated. The following later detailed 5 steps
should do it:

1. `Start PulseAudio in the boot`_
2. `Add D-Bus configuration so that PulseAudio can communicate with BlueZ`_
3. `Configure BlueZ to enable A2DP sink`_
4. `Unblock bluetooth at boot with ConnMan`_
5. `Pair and connect your source device`_

Start ``PulseAudio`` in the boot
================================

The way to start ``PulseAudio`` in the boot is to use systemd service
file. In this example service file we start ``PulseAudio`` and don't
let the daemon exit when in idle (which is normal
behavior). ``PulseAudio`` will just go to "sleep"::

  pulseaudio
  [Unit]
  Description=Pulse Audio

  [Service]
  Type=simple
  ExecStart=/usr/bin/pulseaudio --system --disallow-exit --disable-shm --exit-idle-time=-1

  [Install]
  WantedBy=multi-user.target

Copy the ``pulseaudio.service`` file to::

  /etc/systemd/system/

and enable it by::

  systemctl enable pulseaudio.service

For this particular use case we are starting ``PulseAudio`` in system
mode and including bluetooth modules to the system.pa file.

system.pa can be found from::

  /etc/pulse/

Add the following lines to the system.pa to enable bluetooth::

  .ifexists module-bluetooth-policy.so
  load-module module-bluetooth-policy
  .endif

  .ifexists module-bluetooth-discover.so
  load-module module-bluetooth-discover
  .endif

Add ``D-Bus`` configuration so that ``PulseAudio`` can communicate with ``BlueZ``
=================================================================================

Copy ``D-Bus`` configuration file (name it for example as
``pulseaudio-bluetooth.conf``) to::

  /etc/dbus-1/system.d/

 Contents of the file should be the following::

   <busconfig>
     <policy user="pulse">
       <allow send_destination="org.bluez"/>
     </policy>
   </busconfig>

Configure ``BlueZ`` to enable A2DP sink
=======================================

``BlueZ`` needs configuration to enable A2DP sink feature.
This can be done by creating file ``audio.conf```and copying it to::

  /etc/bluetooth/

With following contents::

  [General]
  Enable=Source

Unblock bluetooth at boot with ``ConnMan``
==========================================

By default the bluetooth radio is soft blocked. To enable it in the
boot you can change ``ConnMan`` configuration file (called ``settings``
in /var/lib/connman/) by changing the following line::

  [Bluetooth]
  Enable=false

to::
  
  [Bluetooth]
  Enable=true

Pair and connect your source device
===================================

For pairing you can use ``BlueZ`` tools of your choice. For example
with bluetoothctl you can set the bluetooth chip to be discoverable
and scan the surrounding devices. ``BlueZ`` test tools also include
simple-agent (Python) which you can use for easy pairing. Starting the
simple-agent with --noinputoutput option enables you to pair and
connect without user input from the bluetooth speaker. When you are
paired and connected ``PulseAudio`` will get notification from ``D-Bus``
and setup the A2DP audio path automatically and you can just start
playback from your connected device.

.. _`mraa`: https://github.com/intel-iot-devkit/mraa

If you want to build your own speaker pairing software one good choice
is to use Python with ``D-Bus`` (to communicate to ``BlueZ``) and
`mraa`_ to get button presses for simplified UI experience. Check
``BlueZ`` simple-agent and ``mraa`` Python examples for ideas how to
do this.

If you plan to use above Python tools you need to add the following
to your local.conf::

  REFKIT_IMAGE_GATEWAY_EXTRA_INSTALL_append = " \
    python-dbus \
    python-pygobject \
    bluez5-testtools"

And also to meta-refkit/conf/distro/include/refkit-supported-recipes.txt::

  python-dbus@meta-python
  python-pygobject@openembedded-layer
