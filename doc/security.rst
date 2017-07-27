IoT Reference OS Kit for Intel(r) Architecture Security Technology
##################################################################

Several technologies which can be used to increase the security of
actual products are already enabled in the IoT Reference OS Kit. Which
of these are suitable for a given product depends on the design goals
for that product.

This document summarizes the available technologies and where to find
further information. Developers are encouraged to read the
``.bbclass`` and ``.bb`` files to understand how the different
technologies are integrated and how to configure or use them.

Integrity Protection
====================

The goal of integrity protection is to ensure that a device boots up
using the software and configuration provided by the vendor. Attackers
may try to influence that both when the device is offline (for
example, by mounting and modifying the filesystem of the device) and
when it is online (by running malicious code and writing to the
filesystem).

Read-only Root Filesystem
-------------------------

Protecting a read-only root filesystem is possible with
`dm-verity`_. In this mode, the entire root partition is signed at
build time with a secret private key. The ``refkit-initramfs``
verifies that signature using a public key before enabling access to
the partition. Then at runtime, ``dm-verity`` detects modified blocks
and rejects access to them, which shows up as read errors at the block
level.

.. _dm-verity: https://source.android.com/security/verifiedboot/

In other words, modifications are detected reliably and
immediately. Because the secret key is not on the device, not even the
kernel can modify the protected partition.

How to design a product such that it works with a read-only rootfs is
out of scope for this document.

To use ``dm-verity``, an image must have the ``read-only-rootfs
dm-verity`` ``IMAGE_FEATURES`` and be derived from the
:file:`meta-refkit/classes/refkit-image.bbclass`. The
:file:`meta-refkit/recipes-images/refkit-installer-image.bb` is an
example for an image that is built with ``dm-verity`` enabled.

In development mode (= including :file:`refkit-development.inc`), a
key provided in :file:`meta-refkit/files/dm-verity/private.pem` is
used for signing, which is obviously not secure.

Real products must use their own key. Those can be created for
example with::

  openssl genpkey -algorithm RSA -pass:<your key password> -out private.pem

Then during the build, ``REFKIT_DMVERITY_PRIVATE_KEY`` must be set to
the full path of the resulting :file:`private.pem` and
``REFKIT_DMVERITY_PASSWORD`` must be ``pass:<your key password>`` or
something else that tells openssl how to obtain the key password (see
``PASS PHRASE ARGUMENTS`` in ``man openssl``).

A real product also needs to ensure that its image really activates
``dm-verity``. This is done by booting with the ``dmverity`` boot
parameter, which tells
:file:`meta-refkit/recipes-image/images/initramfs-framework-refkit-dm-verity.bb`
in ``refkit-initramfs`` that ``dm-verity`` is
required. :file:`refkit-image.bbclass` automatically adds that boot
parameter when building an image with dm-verity enabled. Secure Boot
is required to prevent attackers from replacing the initramfs and/or
changing boot parameters.

Read/write Root Filesystem
--------------------------

A system where the kernel is able to write to the root filesystem is
inherently less secure than a system where not even the kernel has
that capability, because local root exploits then also have the
ability to make permanent changes.

Furthermore, there is no perfect protection against offline attacks,
just some mitigations which make it harder to attack that way. That is
because an IoT device must be able to boot up without external input
(like a user typing in a password), which implies that whatever secret
is used to enable writing must be on the device itself and thus is in
possession of an attacker with physical access to the device. It is
just a question of how hard it is to access the secret.

`IMA/EVM`_ as available at the moment in the Linux kernel cannot protect
against offline attacks because the `directory structure is not
protected`_. It also affects the ability of a system to `recover from
sudden power loss`_ while data gets written. Therefore it is currently
*not* supported.

.. _IMA/EVM: https://sourceforge.net/p/linux-ima/wiki/Home/
.. _directory structure is not protected: https://sourceforge.net/p/linux-ima/mailman/linux-ima-user/thread/1484747488.19478.183.camel%40intel.com/#msg35611386
.. _recover from sudden power loss: https://www.youtube.com/watch?v=N8V0W0p3YBU&t=1115

Whole-disk encryption protects against offline attacks as a side
effect, assuming that the attacker cannot gain access to the secret
key, because blocks cannot be decrypted/encrypted and thus files
cannot be accessed and modified without the secret key.

Whole-disk encryption is currently supported when installing to
internal media using the ``image-installer`` command. See
:file:`howtos/image-install.rst` for information about this image installation
method.

The install step is necessary because in order to be more secure, a
per-machine secret key should be used. Using the same key for multiple
machines would increase the damage resulting from leaking that key.

Currently, `LUKS`_ is used for the rootfs partition. Using LUKS has
several advantages:

* ``refkit-initramfs`` can detect whether a partition is encrypted
  and uses the partition accordingly

* LUKS tools have sane default parameters for encryption

* encryption parameters are stored in the partition
  instead of having to be hard-coded in the installer and
  initramfs, which also simplifies updates (initramfs will
  always use the parameters that were used when creating
  the partition)

The downside is a higher risk for data loss, because the LUKS header
blocks are required for mounting the partition. This could be avoided
by setting up ``dm-crypt`` directly, which currently is not supported
out-of-the-box.

.. _LUKS: https://gitlab.com/cryptsetup/cryptsetup/blob/master/README.md

By default, ``refkit-initramfs`` does not enforce the use of
encryption. That is because the images are meant to be usable both
after flashing to removable media (no encryption) and after
installation (optionally with encryption). If encryption is meant to
provide integrity protection, booting without encryption should be
disabled by adding the ``use_encryption`` boot parameter to the
``APPEND`` variable of an real product image. Otherwise an attacker
could replace the entire rootfs and then boot into that.

To unlock the LUKS partition, a secret key is
needed. ``image-installer`` and the corresponding
:file:`meta-refkit/recipes-image/images/initramfs-framework-refkit-luks.bb`
can use a fixed passphrase. To use that, invoke ``image-installer`` with::

  FIXED_PASSWORD=yes image-installer

Obviously this is not secure and only useful for testing. Something
that may be secure enough for real products (depending on the threat
model for the product) is storing the secret key in a TPM chip. At the
moment, TPM 1.2 is supported. If ``image-installer`` finds a TPM
device, it will take over ownership of the TPM and use it to store a
randomly generated key in a fixed NVRAM slot. The assumption is that the
new OS installation has full control over the TPM and does not need to
share it with other OS installations.

When booting, the initramfs will retrieve the key and then prevent
further access to it, using the TPM ``READ_STCLEAR`` protection
feature for this particular slot. The effect is that even if an
attacker gains access to the TPM at runtime, reading the key again
gets denied by the TPM chip itself.

The key remains in kernel memory and it is the kernel's responsibility
to not leak it during a runtime attack. In addition, the kernel must
prevent an attacker from modifying files at runtime, because such
changes cannot be detected during the next boot.

UEFI Secure Boot
================

.. note::

This section talks about UEFI signing keys. If the reader is not familiar
with the keys involved in UEFI Secure Boot, a good blog post about the meaning
of all UEFI keys can be found in `UEFI Keys`_.

.. _UEFI Keys: https://blog.hansenpartnership.com/the-meaning-of-all-the-uefi-keys/

.. note::

UEFI Secure Boot in Refkit assumes the device is not locked by Microsoft
(PK/)KEK keys but the users are allowed to enable secure boot with their
own PK/KEK/DB keys. Also, for the same reason, the ``shim`` UEFI Secure Boot
approach used in many Linux distributions is not implemented.

The approach taken in images derived from :file:`refkit-image.bbclass`
is to build a single UEFI application, the so called "UEFI combo
application". This application contains:

* systemd-boot (formerly known as gummiboot) EFI stub

* Linux kernel

* initramfs

* fixed boot parameters

* Runtime Machine Configuration (RMC) database with additional
  boot parameters which get activated depending on the current machine

This UEFI combo application gets loaded directly by the firmware,
without any intermediate boot loader involved. This approach is fast,
simple and can be secured by signing the UEFI combo application.

Signing
-------

The signing of the UEFI combo application can be enabled by setting
``secureboot`` image feature for the image/profile that runs on a device
that has UEFI Secure Boot enabled.

After that, the signing is part of the image build process and the UEFI
combo application is automatically signed using `sbsigntool`_. If the
build mode is a development build, the signing uses untrusted/self-signed
signing certificates provided in ``meta-refkit/files/secureboot/``.

For a final product (in production mode) proper signing keys need to be set.
This is explained in the example below.

.. _sbsigntool: https://git.kernel.org/pub/scm/linux/kernel/git/jejb/sbsigntools.git

Example
-------

To enable UEFI Secure Boot signing globally for all profiles, set:

``REFKIT_IMAGE_EXTRA_FEATURES += "secureboot"``

in ``conf/local.conf``. To use a custom DB key, additionally set:

``SECURE_BOOT_SIGNING_KEY``
``SECURE_BOOT_SIGNING_CERT``

The signing tool uses a 2048bit RSA private key (``SECURE_BOOT_SIGNING_KEY``) and a
PEM formatted X.509 signature (``SECURE_BOOT_SIGNING_CERT``). When deploying the DB
keys on the device, use the DER formatted X.509. See ``meta-refkit/files/secureboot/gen-keys-helper.sh`` for more details on how the test keys can be created.

Firewall support
================

Default firewall is nftables. The default firewall ruleset itself is
quite basic: only incoming IPv4 and IPv6 traffic is filtered.
Applications must by themselves request the permissions they need by
dropping an nftables script to directory ``/usr/lib/firewall/services/``
or ``/etc/firewall/services/``. The nftables script should be named with
the package name to avoid file name conflicts.

There are two main ways for writing the script. First way is the
fastest, and is suitable for applications and services which only need
to have certain TCP or UDP port ranges open. The service has a chain
which contains the rules for processing the packet. The chain is then
added as a jump target to tcp map (``tcp_service_map``) or udp map
(``udp_service_map``), which map from port numbers or well-known
services to the chains. In this example, tcp port 22 (ssh) is mapped to
chain ``openssh-sshd``, which then accepts connections from LAN
interfaces. The interface definitions are included from
``zones.ruleset``.

.. code:: nft

    #!/usr/sbin/nft

    table inet filter {
        include "zones.ruleset"
        chain openssh-sshd {
            iif @ZONE_LAN accept;
       }
    }
    
    add element inet filter tcp_service_map {ssh : jump openssh-sshd};

The second way is to set up a new input chain with priority 0 and policy
``accept``. The chain must tag packets belonging to the service there
with mark ``accept_packet``. This method is especially suitable for
services which require network traffic other than tcp or udp, such as
ICMP packets. It carries a performance penalty, however. The following
example is equivalent with the previous example.

.. code:: nft

    #!/usr/sbin/nft
    
    table inet filter {
        include "zones.ruleset"
        chain openssh-sshd {
            type filter hook input priority 0; policy accept;
            tcp dport ssh iif @ZONE_LAN mark set $accept_packet;
        }
    }
