Installing the Images
=====================

Once you have the :file:`.wic` profile image built you need to get it
onto your hardware platform, typically by using removable media such as a
USB thumb drive or SD card.

The recommended way to do this is with the :command:`bmaptool` command from `bmap-tools`_.
A copy of this utility is available in the :file:`deploy/tools` folder after a Yocto Project build
for your image is finished.



The ``bmaptool`` program automatically handles copying either compressed or uncompressed ``wic`` images to
your removable media.  It also also uses a generated ``image.bmap`` file containing a checksum for
itself and for all mapped data regions in the image file, making it possible to verify data integrity
of the downloaded image. Be sure to use this ``.bmap`` file along with the image for your device.


#. Connect your USB thumb drive or SD card to your Linux-based development system
   (minimum 4 GB card required, for some images 8 GB card might be required).
#. If you're not sure about your media device name, use the :command:`dmesg` command to view the system log
   and see which device the USB thumb drive or SD card was assigned (e.g. :file:`/dev/sdb`)::

      $ dmesg

   or you can use the :command:`lsblk` command to show the block-level devices; a USB drive usually
   shows up as ``/sdb`` or ``/sdc``
   (almost never as ``/sda``) and an SD card would usually show up as :file:`/dev/mmcblk0`.

   Note: You should specify the whole device you're writing to with
   :command:`bmaptool`:  (e.g., :file:`/dev/sdb` or
   :file:`/dev/mmcblk0`) and **not** just a partition on that device (e.g., :file:`/dev/sdb1` or
   :file:`/dev/mmcblk0p1`) on that device.

#. The :command:`bmaptool` command will overwrite all content on the device so be careful specifying
   the correct media device. The ``bmaptool`` opens the removable media exclusively and helps prevent
   writing on an unintended device. After verifying your removable media device name, you'll need
   to ``umount`` the device before writing to it.

   In the example below, :file:`/dev/sdb` is the
   destination USB device on our development machine::

      $ sudo umount /dev/sdb*
      $ sudo -E bmaptool copy <image> /dev/sdb

.. note::
    The :command:`bmaptool` is intelligent enough to recognize images in different
    formats, including compressed images (.gz, .bz2, .xz).


Unplug the removable media from your development system and you're ready to plug
it into your target system.

.. _bmap-tools: http://git.infradead.org/users/dedekind/bmap-tools.git/blob/HEAD:/docs/README

Using dd to Create Bootable Media
=================================

While using ``bmaptool``  to create your bootable media is preferred because it's faster and
includes a checksum verification, you can also use the traditional :command:`dd` command instead :

#. Connect your USB thumb drive or SD card to your Linux-based development system
   (minimum 8 GB card required).
#. If you're not sure about your media device name, use the :command:`dmesg` command to view the system log
   and see which device the USB thumb drive or SD card was assigned (e.g. :file:`/dev/sdb`)::

      $ dmesg

   or you can use the :command:`lsblk` command to show the block-level devices; a USB drive usually
   shows up as ``/sdb`` or ``/sdc``
   (almost never as ``/sda``) and an SD card would usually show up as :file:`/dev/mmcblk0`.

   Note: You should specify the whole device you're writing to with
   :command:`dd`:  (e.g., :file:`/dev/sdb` or
   :file:`/dev/mmcblk0`) and **not** just a partition on that device (e.g., :file:`/dev/sdb1` or
   :file:`/dev/mmcblk0p1`) on that device.

#. The :command:`dd` command will overwrite all content on the device so be careful specifying
   the correct media device. In the example below, :file:`/dev/sdb` is the
   destination USB device on our development machine::

      $ sudo umount /dev/sdb*
      $ sudo dd if=<image>.wic of=/dev/sdb bs=512k
      $ sync

Unplug the removable media from your development system and you're ready to plug
it into your target system.
