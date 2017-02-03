Networking
##########

Set up network with `systemd-networkd` only
===========================================

By default IoT Reference OS Kit comes with connman as a network manager which fits nicely
use cases for portable devices. In case your device doesn't move often or
there are plans to run containers on the device with `systemd-nswpan` you
might want to use systemd's networking capabilities only via
`systemd-networkd` and `systemd-resolved`:

1. Remove `connman` from `RDEPENDS` of the `packagegroup-core-connectivity.bb`
   recipe;
2. Include `conf/distro/include/systemd-networking.inc` in your `local.conf`.
   This file basically enables compiling `systemd-networkd` and
   `systemd-resolved` in the systemd recipe::

     PACKAGECONFIG_append_pn-systemd = " networkd resolved"

3. Then on the target device configure `systemd-networkd` by installing files in
   `/etc/systemd/network/` folder.

Look for the details of networking configurations in the `systemd.network`
man page. For example, in order to configure an Ethernet interface getting
its IP address via DHCP you need to install a file
`/etc/systemd/network/wired.network` with the following content::

  [Match]
  Name=en*

  [Network]
  DHCP=ipv4

Then restart the `systemd-networkd` daemon::

  root@intel-corei7-64:~# systemctl restart systemd-networkd

With such settings `systemd-resolved` will take care of DNS configuration
if the used DHCP server is configured to announce who serves DNS requests.

Wireless intefaces and `systemd-networkd`
-----------------------------------------

`systemd-networkd` doesn't have special support for Wifi interfaces, but
treats them as ordinary network interfaces connected to media. Thus
configuring a wireless interface is a bit more complex task since in case of
a client device it requires configuring `wpa_supplicant` first:

1. On the target device install a configuration file for the Wifi interface into
   `/etc/wpa_supplicant/wpa_supplicant-<interface_name>.conf`.

   The name of the interface you can check with the command `ip link`. E.g. on
   an Intel(r) 500 series device it's always `wlp1s0` and the file
   `/etc/wpa_supplicant/wpa_supplicant-wlp1s0.conf` should contain something
   like::

     network={
             ssid="YourAccessPointName"
             psk="very-secret-pass-key"
     }

2. Enable and start the service for `wlp1s0`::

     root@intel-corei7-64:~# systemctl enable wpa_supplicant@wlp1s0
     root@intel-corei7-64:~# systemctl start wpa_supplicant@wlp1s0

3. Now you can configure networking by installing
   `/etc/systemd/network/wireless.network` with the following content::

     [Match]
     Type=wlan

     [Network]
     DHCP=ipv4

4. Restart `systemd-networkd`::

     root@intel-corei7-64:~# systemctl restart systemd-networkd

Configure 6lowpan central node
==============================

In case you want to setup a gateway to BLE-enabled devices supporting
the IPSP profile and given a BLE node is advertising follow the steps:

1. Make sure the bluetooth adapter is unblocked and can be powered::

     # rfkill unblock bluetooth

2. Make sure the bluetooth_6lowpan driver is loaded on the gateway device::

     # modprobe bluetooth_6lowpan

3. Enable 6lowpan::

     # echo 1 > /sys/kernel/debug/bluetooth/6lowpan_enable

4. Connect to the BLE node::

     # echo -e "connect 00:AA:BB:XX:YY:ZZ\n" | bluetoothctl

   Theoretically this step is not needed, but it's required at least
   in order to connect to a node running ZephyrOS v1.6.0. With future
   releases of ZephyrOS or Linux kernel the situation might change.

5. Create a 6lowpan connection to the node::

     # echo "connect 00:AA:BB:XX:YY:ZZ 1" > /sys/kernel/debug/bluetooth/6lowpan_control

At this point a new btX interface representing a point-to-point connection
to the node should emerge. You can test it with broadcast pings::

  # ping6 -I bt0 ff02::1
