Configuring IoT Refkit images
#############################

Many packages in IoT Refkit come with a default set of configuration
files. This document gives guidance for configuring a Refkit image with
custom package configuration files.

Using .bbappend files to override package configuration
=======================================================

If you have only a limited set of packages which you need to configure,
you can create ``.bbappend`` files which append the recipes for each
package which you want to modify. A usual way to change the
configuration is to change the install phase to replace or remove the
default configuration files.

You can add the ``.bbappend`` files to your own customization layer and
use ``do_install_append()`` for modifying package configuration.

.. code::

    do_install_append () {
        install -d ${D}${sysconfdir}
        echo "some configuration" > ${D}${sysconfdir}/config_file
        ...
    }

Using virtual packages
======================

Some recipes in IoT Refkit and other Yocto layers have the configuration
split into separate configuration packages. For example, see
`nftables-settings-default recipe
<../../meta-refkit-core/recipes-security/nftables-settings-default/nftables-settings-default_0.1.bb>`_.
In these cases, if you want to replace the configuration fully, you can
create your own configuration package (say ``nftables-settings-custom``)
and just use it in place of the default configuration package.

Other recipes, where having a configuration package is mandatory, take
this further and use ``VIRTUAL_RUNTIME`` convention to enforce that a
configuration package will be installed to the target. For example,
consider `groupcheck recipe
<../../meta-refkit-core/recipes-security/groupcheck/groupcheck_git.bb>`_,
which has the following lines:

.. code::

    VIRTUAL-RUNTIME_groupcheck-settings ?= "groupcheck-settings-default"
    RDEPENDS_${PN} += "${VIRTUAL-RUNTIME_groupcheck-settings}"

If a configuration package (say ``groupcheck-settings-custom``) is made,
it needs to be set to be the required configuration package. This is
done by changing ``local.conf`` or other distro configuration file to
override the particular ``VIRTUAL_RUNTIME`` variable:

.. code::

    VIRTUAL-RUNTIME_groupcheck-settings = "groupcheck-settings-custom"

Image configuration during root filesystem creation
===================================================

An alternative to configuring individual packages is the configuration
of the entire image during rootfs creation. The image recipes can be
appended as any other recipe. This is the correct approach if you have
several files in different packges which you need to change or if you
just want to keep the configuration changes in one place.

One practical way for implementing a certain configuration would be to
add it as a ``.bbclass`` file, which would then be inherited by all
images which require that configuration. For example, you can create
``custom-config.bbclass`` file and add a Python task function to do the
necessary configuration changes there:

.. code::

    python change_image_configuration () {
        etcdir = oe.path.join(d.getVar("IMAGE_ROOTFS"), d.getVar("sysconfdir"))
        ...
    }

    ROOTFS_POSTPROCESS_COMMAND_prepend = "change_image_configuration;"

You can then inherit the class directly into your own image recipes.

A drawback of this method is that the image is changed after the
packages are installed. This means that you can't use package-based
methods for updating devices, but should instead use `file- or
block-based update mechanisms
<https://wiki.yoctoproject.org/wiki/System_Update>`_. Supported system
update mechanisms IoT Refkit are documented in `system-update.rst
<../system-update.rst>`_.
