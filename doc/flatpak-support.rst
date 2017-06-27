Flatpak Support in IoT Reference OS Kit
#######################################

IoT Reference OS Kit supports installing and running applications packaged
as `flatpaks <http://flatpak.org>`_.

Flatpak in a Nutshell
----------------------

Flatpak is a framework for building, distributing, and managing applications.
It conceptually splits the software stack into

* a runtime: the core/common bits,
* an SDK: bits necessary for building software for a runtime,
* the applications themselves

Flatpak decouples the life-cycle of the application from that of the
underlying distro. By doing so it enables updating the distro and the
(flatpak) applications independently from each other.

Additionally flatpak provides application sandboxing out of the box and
relies largely on `ostree <http://ostree.readthedocs.io>`_ for providing
an infrastructure for application (binary) version control, distribution
and deployment.

For more information and details see the corresponding documentation of
flatpak and ostree.

Basic Flatpak Support
---------------------

Basic flatpak support includes recipes for flatpak and its runtime and
buildtime dependencies as well as Yocto helper classes for building
flatpak-enabled versions of images. It can be enabled by the *flatpak*
distro feature. Since it has additional prerequisites, the easiest way
to enable it is to include :file:`meta-flatpak/conf/distro/include/flatpak.inc`
in your build configuration.

Flatpak Image Variants
----------------------

When the *flatpak* distro feature is enabled ``meta-flatpak`` defines
two flatpak-specific image variants:

* *flatpak-runtime*: a flatpak-enabled image to be used on a target device
* *flatpak-sdk*: a *flatpak SDK runtime* to be used on a (development) host

The *flatpak-runtime* variant adds flatpak, ostree, etc., all the necessary
runtime bits to run flatpak, to the image. With such an image on a target
device you should be able to invoke flatpak to carry out the normal flatpak
operations, including defining flatpak remotes, installing, uninstalling and
running flatpak applications.

The *flatpak-sdk* variant adds the compiler toolchain, developement packages
debug symbols, version control software, etc., in short everything you might
need to compile and turn your applications into flatpaks intended to be
installed on the *flatpak-runtime* image variant.

You can refer to these image variants by appending their name to that
of the base image. For instance you can build both of these variants for
*refkit-image-gateway* by running:

```
bitbake -c refkit-image-gateway-flatpak-runtime refkit-image-gateway-flatpak-sdk
```

Extra Flatpak-based Functionality - Flatpak Session
---------------------------------------------------

In addition to stock flatpak support, *meta-flatpak* provides support
for running a set of flatpaks from a common remote using a dedicated
user, monitoring the remote for updates and/or new applications and
automatically installing and activating those.

Support for this extra set of functionality is controlled by the
*flatpak-session* distro feature. The easiest way to enable it is to
include :file:`meta-flatpak/conf/distro/include/flatpak.inc` in your
build configuration.

See the comment section in :file:`meta-flatpak/classes/flatpak-config.bbclass`
for more details about the necessary steps or configuration you need to go
through to have a *flatpak session* set up for a remote on your device.

Caveats
-------

In addition to the basic flatpak dependencies a *flatpak-runtime* variant
also pulls into the image a systemd service which is used to activate a
'fake' flatpak runtime. This is basically a few files and bind mounts that
are used to emulate an flatpak-installed *flatpak runtime* for the image
itself. If you don't want it in your image, you can exclude it by putting
an appropriately crafted _remove for your image in your build configuration.
Note however, that either this fake runtime or the real flatpak runtime for
the image needs to be installed, otherwise you cannot install and run
flatpaks compiled for your image.
