Yocto Compatible 2.0
====================

The main goal of the next revision of the Yocto compliance program,
called "Yocto Compatible 2.0", is to increase inter-operability of
different layers. One key aspect is that a layer must not change a
build configuration merely because it gets added to a build. Instead,
only some explicit build configuration change (like setting distro
flags or including a .inc file provided by the layer) may cause the
build to change.

All meta-refkit layers are "Yocto Compatible 2.0". In addition to
that, it is guaranteed that including :file:`refkit-config.inc` will
also not change the build. It merely provides support for choosing
some of the distro features implemented in intel-iot-refkit, without
actually turning them on. That choice is still left to the developer
or distro.

The "Layer Overview and Reuse" section in :file:`introduction.rst`
explains how to use this. This document is about the implementation.


Implementation
==============

Optional ``.bbappends``
-----------------------

:file:`refkit-config.inc` contains global distro settings, including
"normal" re-configuration of recipes via ``PACKAGECONFIG``
changes. Everything that goes beyond that needs to be in a
``.bbappend``. Often these are workarounds or new recipe features that
long-term might be more suitable for inclusion into the upstream
recipe.

Such ``.bbappends`` go into ``meta-refkit-core`` (when they are common
to multiple profiles) or individual profile layers. Normally a layer
can only provide ``.bbappends`` for recipes that are known to be
available. A fatal error aborts parsing when no ``.bb`` file is found
for a ``.bbappend``, to catch cases where the original ``.bb`` was
renamed and the ``.bbappend`` must be updated.

``meta-refkit-core/bbappends`` contains a directory hierarchy that
matches the structure of upstream layers that are used in
``intel-iot-refkit``. ``BBFILES_DYNAMIC`` instead of the normal
``BBFILES`` is used to enable ``.bbappend`` files only when the
corresponding layer is present in a build, so one still gets the error
when the ``.bb`` file changes, but not when the entire layer is
missing.

Avoiding Signature Changes
--------------------------

:file:`refkit-config.inc` and ``.bbappend`` files must not change the
build when not explicitly enabled via distro features. This is checked by
comparing task signatures.

There are several different techniques for avoiding task signature
changes, listed here in order of increasing complexity. Use the simplest
approach that works.

#. conditional ``_append/remove``

   :file:`refkit-config.inc` defines certain distro features (for
   example, ``refkit-config``) which get turned into overrides with
   ``df-`` as prefix. By adding those overrides to ``_append`` or
   ``_remove``, one can limit that change to configurations where
   the feature is active::

     do_install_append_df-refkit-config () {
         ...
     }

   Combining multiple overrides applies when all overrides are set
   ("and" semantic)::

     do_install_append_df-refkit-firewall_df-refkit-gateway () {
        ...
     }

   Repeating the variable with different conditions applies the change
   when one or more conditions are met ("or" semantic). But beware
   that values will be appended more than once when more than one
   condition is true. This may be acceptable in some cases, like this
   one::

     EXTRA_OECONF_append_df-refkit-gateway = " --enable-foo"
     EXTRA_OECONF_append_df-refkit-industrial = " --enable-foo"

#. conditional setting of variables

   Setting a variable with an override suffix chooses that value when
   the overrides are active::

      PACKAGECONFIG_pn-foo_df-refkit-config = "bar"

   As before, multiple overrides can be combined again ("and"
   semantic). Assignments with more or more important overrides are
   chosen over less specific assignments (see the bitbake manual for
   details).

   When repeating the same assignment for different cases ("or"
   semantic), a helper variable may be useful to avoid repeating code.
   Use ``refkit_`` or ``REFKIT_`` as prefix for those::

     REFKIT_PACKAGECONFIG_FOO = "bar"
     PACKAGECONFIG_pn-foo_df-refkit-gateway = "${REFKIT_PACKAGECONFIG_FOO}"
     PACKAGECONFIG_pn-foo_df-refkit-industrial = "${REFKIT_PACKAGECONFIG_FOO}"

#. conditional includes

   Manipulating varflags or some operations (like ``addtask``) do not support
   overrides. Such changes can be placed in a .inc file alongside a ``.bbappend``
   and then get included conditionally::

     require ${@oe.utils.all_distro_features(d, 'refkit-gateway refkit-firewall', 'gateway-and-firewall.inc') }
     require ${@oe.utils.any_distro_features(d, 'refkit-gateway refkit-industrial', 'gateway-or-industrial.inc') }
     require ${@oe.utils.all_distro_features(d, 'refkit-config', 'config1.inc config2.inc') }

   As shown here, one can check for one or more distro features and
   include one or more files at once. The semantic depends on the
   function ("or" for ``any_distro_features()``, "and" for
   ``all_distro_features()``). When only one feature is listed,
   both functions behave the same. When the condition is not satisfied,
   these functions return the empty string and nothing gets included.

   They can also be used in a boolean context::

     if oe.utils.all_distro_features(d, 'refkit-config'):
        bb.note('refkit-config is in DISTRO_FEATURES')

   More complex ``${@ }`` expressions are also possible. The two functions
   above are merely helper functions that cover the common cases.

   Beware that includes are executed while parsing. Checking for
   distro features in a ``.bbappend`` is safe because distro features
   are finalized before parsing recipes. For changes affecting the
   base configuration, conditional variable changes with overrides
   have to be used because these conditions are then checked each time the
   variables are used.

   Checking recipe variables is not safe because those might still be
   changed later (for example, in another ``.bbappend``).

#. anonymous Python methods

   Anonymous python methods embedded into a ``.bbappend`` can make
   arbitrary changes to the recipe after checking for some condition.
   In contrast to conditional includes, anonymous Python methods
   are executed at the end of parsing and thus can typically check
   recipe variables. The only caveat is that another method might
   still change those variables.

   This can be used to replace the ``addtask`` directive without
   having to create a separate ``.inc`` file::

     python () {
        if bb.utils.contains('IMAGE_FEATURES', 'ostree', True, False, d) and \
           oe.utils.all_distro_features(d, 'ostree'):
           bb.build.addtask('do_ostree_prepare_rootfs', 'do_image_wic', 'do_image', d)
     }


Testing
=======

``oe-selftest -r refkit_poky.TestRefkitPokySignatures`` applies the
``yocto-compatible-layer.py`` test script to all ``meta-refkit``
layers against a base configuration which mirrors the ``Poky``
distribution. The output in case of a failure contains differences
between task signatures, which usually highlights were some undesired
change is happening.

``oe-selftest`` can be run in a local build configuration, without
affecting the build itself. See ``oe-selftest --list-tests`` for a
full list of tests that can be run this way.

The compatibility tests do not guarantee that actual builds will work,
because they only check syntax, dependencies and task
signatures. Actual building is covered by ``oe-selftest -r
refkit_poky.TestRefkitPokyBuilds`` for two build configurations:

test_common_poky_config
  Building ``refkit-image-common`` using just the plain ``Poky``
  distribution settings (for example, without ``systemd``).

test_common_refkit_config
  Building ``refkit-image-common`` using the ``Poky``
  distribution settings plus :file:``enable-refkit-config.inc``,
  i.e. all refkit distro features set.
