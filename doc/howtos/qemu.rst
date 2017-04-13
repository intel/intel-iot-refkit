Using QEMU
##########

A Refkit wic image can be tested with QEMU as is. For that make sure that the
`ovmf` target has been built::

  $ bitbake ovmf

Then use the command `runqemu` to start a QEMU virtual machine::

  $ runqemu ovmf refkit-image-common wic

This command will ask for superuser permissions, will create a TAP network
interface for the VM automatically and will expose graphical output via a
VNC server listening on localhost.

.. note:: Make sure you run a DHCP server properly configured to listen to
   the dynamically created TAP interface if you need working connectivity.

While TAP interfaces perform best an easier solution would be to use SLIRP
interfaces if all you need is the ability to ssh to your VM. They don't
require having superuser permissions and enable QEMU's built-in DHCP-server.
The following command will provide working connectivity without any
additional setup::

  $ runqemu ovmf refkit-image-common wic slirp

Then connect to the VM with::

  $ ssh root@localhost -p 2222

In order to access VM's serial console add two more options to the
`runqemu` command::

  $ runqemu ovmf refkit-image-common wic slirp serial nographic
