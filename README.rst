intel-iot-refkit
################

This README file contains information on setting up, building, and booting
the IoT Reference OS Kit for Intel(r) Architecture project.

   Only Linux development hosts are currently supported, as documented
   in the `Yocto Project Quick Start Guide`_

Follow the instructions in this document when trying to get familiar with
the IoT Reference OS Kit or when basing a new project on it. Alternatively,
it is also possible to take a subset of the content and add it to other,
existing projects or distributions. For information about the content, see
:file:`doc/introduction.rst`.

.. _Yocto Project Quick Start Guide: http://www.yoctoproject.org/docs/current/yocto-project-qs/yocto-project-qs.html#the-linux-distro

Installing Docker on Linux
==========================

We recommend you build projects in a Docker container. Using Docker provides
a packaged and controlled environment for building an
image and can eliminate development environment issues that
can occur with differing Linux OS distros and versions, different host
compilers, and such. (We also describe `building without docker`_ in the
instructions below.)

Instructions for installing Docker for common Linux distros on your
development machine (including Fedora and Ubuntu) are available at:
https://docs.docker.com/engine/installation/linux.

.. _Optional Docker Configuration: https://docs.docker.com/engine/installation/linux/ubuntulinux/#Optional%20Configurations
.. _configure the DNS server for Docker: https://docs.docker.com/engine/installation/linux/ubuntulinux/#configure-a-dns-server-for-use-by-docker

Follow the instructions for your particular distro. You should also
perform some of listed `Optional Docker Configuration`_ settings:

-   Add your Linux user account into the Docker system group with::

    $ sudo gpasswd -a ${USER} docker
    
    You’ll need to log out and back in for this change to take effect.

-   Inside company firewalls, you’ll need to configure proxies. Follow the
    instructions for Docker at
    https://docs.docker.com/engine/admin/systemd/#http-proxy
    and also set the usual environment variables::
 
    $ export http_proxy=http://proxy.example.com:<port>
    $ export https_proxy=https://proxy.example.com:<port>
    $ export ALL_PROXY=socks://proxy.example.com:<port>

-   Some distributions such as Ubuntu require you to manually
    `configure the DNS server for Docker`_.
    This can be done by adding ``--dns <dns-server-ip-address>``
    to the Docker daemon startup parameters in ``/etc/default/docker``.
    (Check your ``/etc/resolv.conf`` file for system’s specific
    DNS settings.) More information is available here (note that
    Ubuntu 15.10 and later use ``systemd``):
    
    -   https://docs.docker.com/engine/admin/configuring/
    -   https://docs.docker.com/engine/userguide/networking/configure-dns/

Building with Docker
====================

These instructions assume you’ll be working with the sources in a
``~/work/intel-iot-refkit`` directory that you’ll be creating.

Start by cloning the GitHub repos. If you have a previous copy of this
repository without all the submodules, it would be best to remove all
the content of workspace directory and clone it again::

$ export WORKSPACE=$HOME/work/intel-iot-refkit
$ mkdir -p $HOME/work
$ cd $HOME/work
$ git clone --recursive https://github.com/intel/intel-iot-refkit.git
$ cd $WORKSPACE

When Docker is configured properly and all project code is cloned and
available locally, it's time to trigger a build. To do this run the
command from within the ``~/work/intel-iot-refkit`` directory::

Build all pre-configured target images with test suites::

$ docker/local-build.sh

Specify one or more target image(s)::

$ docker/local-build.sh refkit-image-common

.. building witout docker:

Building without Docker
=======================

While not recommended, you can also use Yocto Project bitbake directly.
(Any issues you encounter building this way might not be easily
reproducible and debuggable by other developers using a different
distribution.)

Here are the basic preparation steps::

$ mkdir -p $HOME/work
$ cd $HOME/work
$ git clone --recursive https://github.com/intel/intel-iot-refkit.git
$ cd intel-iot-refkit
$ source oe-init-build-env

Edit ``conf/local.conf`` to select whether to build the production or the development image.
More details about the choices in that file.

Basic build steps::

$ bitbake refkit-image-common

Updating Repositories
=====================

You may need to pull new content from the GitHub repo as it’s updated.
Use the following commands::

$ git pull
$ git submodule update

For more information about Git submodule commands, check this link: 
https://git-scm.com/docs/git-submodule

Installing the Images
=====================

See detailed instructions in `how to install images <doc/howtos/image-install.rst>`_.

Mailing Lists
=============

The project has a mailing list for all project development related discussions.

The mailing list info/subscription page can be found `here`_

.. _here: https://lists.yoctoproject.org/listinfo/intel-iot-refkit

Bug Tracking
============

The project uses the `Yocto Project Bugzilla`_ for feature/enhancement and bug tracking.

If you've found a bug or wish to file an enhancement request, go to Bugzilla
and submit the tickets against Yocto Project Subprojects | `IoT Reference OS Kit component`_.

.. _Yocto Project Bugzilla: https://bugzilla.yoctoproject.org/
.. _IoT Reference OS Kit component: https://bugzilla.yoctoproject.org/enter_bug.cgi?product=IoT%20Reference%20OS%20Kit

Submitting Patches
==================

The project is open to patches and bug fixes. The patches can be submitted as Github
Pull requests in https://github.com/intel/intel-iot-refkit or to the project
mailing list.

Please follow the common Yocto Project/OpenEmbedded Core `Commit Message Guidelines`_.

.. _Commit Message Guidelines: http://www.openembedded.org/wiki/Commit_Patch_Message_Guidelines#Patch_Headers_and_Commit_Messages
