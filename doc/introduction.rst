IoT Reference OS Kit for Intel(r) Architecture Introduction
###########################################################

IoT Reference OS Kit for Intel(r) Architecture (The Reference Kit) is a new
set of Yocto Project metadata layers and infrastructure geared towards IoT
development. The Reference Kit is a preconfigured Yocto Project based platform 
that is easy to take in use and customize further.

The Reference Kit introduces the concept of a "profile" - an image
configuration that demonstrates certain key IoT usage. Examples of planned
profiles are industrial, gateway and computer vision, but others could be
included.

Each profile is defined in its own, self-contained layer. Each layer
defines which other layers it depends on, both in the README.rst (for
humans) and in the layer.conf (for tools like the layer index and Toaster).

The Reference Kit repository is built such that it integrates selected
Yocto Project layers together and ensures that the content works
seamlessly together. All external layers get imported as git
submodules, using a revision that is known to work. Run :command:`git
ls-tree HEAD | grep " commit "` in the ``intel-iot-refkit`` repository to
get the exact revision of each subcomponent that is used.

By default the Reference Kit runs on Intel's `meta-intel BSP`_ platforms.

.. _`meta-intel BSP`: https://www.yoctoproject.org/product/meta-intel-bsp-layer


.. _`Yocto Project release cadence`: https://wiki.yoctoproject.org/wiki/Planning#Roadmaps_and_Schedules
.. _`Yocto Project Bugzilla`: https://bugzilla.yoctoproject.org/
.. _`Yocto Project git`: http://git.yoctoproject.org/

The Reference kit follows the `Yocto Project release cadence`_, keeps
the content in the `Yocto Project git`_ and uses the `Yocto Project Bugzilla`_
for feature and bug tracking.

Layer Overview and Reuse
########################

Layers
------

IoT Reference OS Kit supports using its layers also in other projects
without using the Reference Kit distribution. Each layer is "Yocto
Compatible 2.0", which guarantees that merely adding it to a build
configuration does not change the build unless explicitly requested
(for example, in local.conf, distro configurations, or image recipes).

Some of the content may depend on specific distribution configuration
options. For specific usage instructions, see :file:`profiles.rst`.

Another caveat is that obviously not all combinations can be
tested exhaustively. What gets tested is that each individual
layer can be added to the ``Poky`` Yocto Project reference
distribution and that they do not break a world build.

Full testing of features only happens on the refkit distribution
itself, so that is the recommended starting point for someone who
wants to try out something.

The ``intel-iot-refkit`` repository contains the following layers:

  ``meta-refkit``
    The distribution layer. Depends on all other layers.

  ``meta-refkit-extra``
    Demos that run on top of the Reference Kit distribution and
    thus depends on ``meta-refkit``.

  ``meta-refkit-core``
    Common utility classes and miscellaneous recipes which are not
    profile-specific. The only hard dependency of this layer is
    ``openembedded-core``. :file:`meta-refkit-core/conf/layer.conf`
    automatically detects available layers and enables content
    based on that. When providing recipes via some other layer,
    override the  ``HAVE_...`` variables from that :file:`layer.conf`.
    For example, the ``dm-verity`` support depends on ``cryptsetup``,
    which could be provided either by adding ``meta-security`` or
    copying the recipe into a distro-specific layer. In the latter
    case, ``HAVE_CRYPTSETUP`` has to be set.

  ``meta-refkit-computervision/gateway/...``
    Profile layers. See also :file:`profiles.rst`.

Note that ``meta-<something>`` is the directory containing the layer
called ``<something>``, although in practice ``meta-<something>`` and
"the ``<something>`` layer" are often used interchangeably.


Common Features
---------------

The reusable part of the distro configuration (package configuration,
default distro features, etc.) is made available to other distros via
:file:`meta-refkit-core/conf/distro/include/refkit-config.inc`.

To reuse the distro configuration in addition to the layer content:

* Add ``require "conf/distro/include/refkit-config.inc"``, *and*
* use enable same distro features as the refkit distro (in particular, systemd)
  with ``require "conf/distro/include/enable-refkit-config.inc``,
* *or* choose individual distro features to match your needs.

These changes can go into file:`local.conf` or a custom distro
configuration file.

See file:`refkit-config.inc` for a description of the currently
supported special distro features.


Supported Recipes
-----------------

The Reference Kit distribution uses ``supported-recipes.bbclass`` to
control which recipes are part of the distribution.  It uses explicit,
complete lists of recipes that are part of a project and thus is
easier to review and maintain. Accidentally pulling in additional
content triggers a warning or error (depending on the configuration)
which explains the dependency that pulled in the content.

For example, although several layers from ``meta-openembedded`` are
required for a build, only a well-chosen and tested subset of it is
really needed. The rest will not be part of a ``bitbake world`` build
either.

This mechanism is completely optional. The individual layers do not
track the recipes that they need, only the ``refkit`` distro layer and
its ``refkit-extra`` add-on layer have such a list in
:file:`meta-refkit/conf/distro/include/refkit-supported-recipes.txt`
and
:file:`meta-refkit-extra/conf/distro/include/refkit-extra-supported-recipes.txt`.

Projects which want to use the same mechanism can do so via their
distro or local configuration, similar to how :file:`refkit.conf` in
``meta-refkit`` does it.
