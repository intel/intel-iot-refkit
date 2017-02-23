IoT Reference OS Kit for Intel(r) Architecture Hardware Support
###############################################################

IoT Reference OS Kit supports a selection of hardware that have been tested to
work to a limited extent, specified here. IoT Reference OS Kit may also work
on other Intel(r) Architecture hardware, but it has not been tested.

System boards
=============

This secion lists system boards that are supported.

MinnowBoard Turbot
------------------

Supported BIOS version is 94. Following on-board devices/interfaces have been
tested to work.

 - Serial console
 - USB 2.0 and 3.0
 - Ethernet
 - GPU with HDMI output
 - Audio output over HDMI
 - microSD
 - GPIO
 - PCIe (with Silverjaw Lure)

Following on-board devices/interfaces have not been tested.

 - I2C
 - SPI
 - I2S
 - PWM
 - SATA
 - XDP

There are currently no known non-functional devices/interfaces.

Intel 570x
----------

Supported BIOS version is 163. Following on-board devices/interfaces have been
tested to work.

 - Serial console
 - USB 3.0 Type-A
 - GPU with HDMI output
 - Audio output over HDMI
 - WiFi/BT adapter
 - eMMC
 - microSD
 - GPIO

Following on-board devices/interfaces have not been tested.

 - I2C
 - SPI
 - I2S
 - PWM
 - MIPI DSI
 - MIPI CSI

Following on-board devices/interfaces are known not to work.

 - USB 3.1 Type-C

Peripherals
===========

USB Mass Storage
----------------

Devices compliant with USB Mass Storage device class have been tested to work.

USB Communication
-----------------

Devices compliant with USB Communication Device Class (CDC) have been tested
to work.

USB Audio
---------

Devices compliant with USB Audio Class 1.0 and 2.0 should work, but have not
been tested.

USB Video
---------

Devices compliant with USB Video Class have been tested to work.

USB Ethernet
------------

Following USB Ethernet adapters have been tested to work.

 - ASIX AX8817X

USB Serial
----------

Following USB Serial adapters have been tested to work.

 - FTDI

PCIe Wireless
-------------

Following PCIe wireless adapters have been tested to work.

 - Intel(R) Dual Band Wireless N 7260 (WiFi)

