=============
System Update
=============

The goal is to support two system update mechanisms out of the box:

#. file-based for read/write rootfs
#. block-based for read-only rootfs

These two approaches have pros and cons that are inherent in their
design. For example, only a block-based update mechanism is compatible
with integrity protection via ``dm-verity``. File-based mechanisms are
typically more efficient at the expense of additional complexity,
support different partition sizes with a single update stream and can
prepare an update in a single partition while the partition is in
use. For a more complete discussion of these aspects, see
https://wiki.yoctoproject.org/wiki/System_Update and in particular the
"Surviving in the Wilderness: Integrity Protection and System Update"
talk linked to on that page.

File-Based Update: OSTree
=========================

Why OSTree?
-----------

OSTree is attractive for a number of reasons:

#. OSTree worked without modifications, seems to have a
   healthy upstream development community and good documentation.
   Commercial support for use with Yocto is available when needed,
   but not required.

#. The OSTree approach of preparing a new complete directory tree in
   the background and then switching to it in a reboot is truly
   atomic.

#. OSTree supports all kind of directory tree changes during an OS
   update.

#. OSTree supports an arbitrary number of branches in a single
   repository and thus can store the update streams of different image
   configurations efficiently in a single repository. OSTree system
   update also integrates nicely with using ``flatpak`` for
   applications.

#. Different release strategies and pruning of old content are directly
   supported by the OSTree tool, see `repository management`_.

.. _`repository management`: https://ostree.readthedocs.io/en/latest/manual/repository-management/

OSTree Integration
------------------

OSTree system update support in IoT Refkit gets enabled when the
``ostree`` distro feature is set. In addition, the ``usrmerge`` distro
feature must be set because OSTree relies on that.

Some part of the functionality overlaps with meta-updater_, but that
part is fairly small and did not justify pulling in another complex
layer. Most of the code is about supporting the way how IoT Refkit
works:

* Booting is done without a boot loader. The UEFI firmware directly
  loads the UEFI combo app, a combination of kernel, initramfs and
  boot parameters.

* The initramfs is based on the ``initramfs-framework`` in ``openembedded-core``.

* Images are created with the wic image type.

.. _meta-updater: https://github.com/advancedtelematic/meta-updater


The OSTree support is provided by the following components:

OSTree tool
  The unmodified upstream OSTree tool is sufficient. The recipe for
  it in ``intel-iot-refkit`` is from the ``meta-flatpak`` layer, but
  could also come from elsewhere. It is assumed that ``ostree`` and
  ``ostree-native`` recipes can be built once the ``ostree`` distro
  feature is set, otherwise they are not needed.

``initramfs-framework-ostree.bb``
  This extends the ``refkit-initramfs`` so that it detects OSTree-enabled
  images and bind-mounts the deployed directory tree at the normal
  places (for example, :file:`/usr`) so that booting can continue. The
  intended directory is chosen based on what is deployed, i.e. not via
  the ``ostree`` boot parameter as usual. That is because boot parameters are
  compiled into the UEFI combo app and cannot be changed. To keep the OSTree tool
  working in the running OS, the initramfs also overrides :file:`/proc/cmdline`
  with a version that has the expected ``ostree`` boot parameter.

``refkit-ostree_git.bb``
  Some on-target helper script, partly used by the initramfs and partly
  used as wrapper around the actual :command:`ostree`.

``ostree-image.bbclass``
  This helper class gets inherited automatically by ``refkit-image.bbclass``
  when the ``ostree`` distro feature is set. When also the ``ostree` image
  feature is set, then image creation is changed:

  * The rootfs gets constructed as usual in ``do_rootfs`` and ``do_image``.
  * In ``do_ostree_prepare_rootfs``, the files that need to be committed to
    the OSTree repository for the current image build get split out into a
    :file:`ostree-sysroot` directory in the image work directory. Then
    a new OSTree-enabled on-target rootfs gets created in :file:`rootfs.ostree`.
  * In the ``do_image_wic`` task, that rootfs then gets turned into an image
    using wic.
  * In parallel to ``do_image_wic``, ``do_ostree_publish_rootfs`` commits
    the sysroot to the public OSTree repo from where older installations
    can pull it.

OSTree Usage
------------

See the comments in ``ostree-image.bbclass`` for instructions on how
to configure the image creation. In particular, image signing and
publishing the permanent OSTree repository require some planning and
customization.

In development images, the default is to use a generated GPG key from
:file:`tmp-glibc/deploy/gnupg/` and a "permanent" OSTree repository in
:file:`tmp-glibc/deploy/ostree-repo/`. In other words, removing
:file:`tmp-glibc` really starts from scratch.

Extra work is necessary when images from previous builds are still
meant to be updateable:

#. The GPG key must be stored elsewhere (see ``OSTREE_GPGDIR`` and
   ``OSTREE_GPGID``).
#. The public OSTree repo must be stored elsewhere (see ``OSTREE_REPO``) *or*
#. after a successful build, the new commit in :file:`tmp-glibc/deploy/ostree-repo/`
   must be moved to a different, more permanent OSTree repo with the
   :command:``ostree`` tool's `repository management`_ commands.
   While it would be possible to run the :command:``ostree`` that was built
   by :command:``bitbake``, getting access to it would be a bit complicated,
   so it is recommended to install OSTree packages for the distribution on which
   the repository gets managed.

OSTree supports calculating deltas_ between releases to speed up the
download. This is not done automatically and needs to be integrated
into the release process for a product.

.. deltas: https://ostree.readthedocs.io/en/latest/manual/repository-management/#derived-data-static-deltas-and-the-summary-file

Once a device has booted into an OSTree-enabled image, the
:command:`ostree` command can be used as usual. Updates are configured
in :file:`/ostree/repo/config` to pull new OS releases from the
``OSTREE_REMOTE`` URL that was set at build time.

Beware that system updates should be done with :command:`refkit-ostree
update`, because that will also update the UEFI combo app.

OSTree Filesystem
-----------------

Some parts of the rootfs are special:

:file:`/var`, :file:`/home`
   These are read/write directories that are seeded in images from the current build,
   but then do not get updated as part of a system update.

:file:`/etc`
   The content of  :file:`/etc` can be modified on a device to configure it. In
   addition, the original, unmodified content of :file:`/etc` in each OS build is
   part of the OSTree repo. During each update, OStree does a three-way merge
   between old release, new release and the local content of :file:`/etc`. The
   merge strategy is fairly limited. It guarantees that unmodified content stays
   the same as in the original OS (including removing files or changing their type),
   but once modified, the locally modified file continues to be used unchanged,
   i.e. there is no diff/patch of file content.

Debugging OSTree System Update
------------------------------

The :command:`oe-selftest -r refkit_ostree.RefkitOSTreeUpdateTestAll`
will run an update test under ``Qemu`` that covers various aspects at
once. When debugging a particular problem, it might be easier to use
the tests in the ``refkit_ostree.RefkitOSTreeUpdateTestIndividual``
class. See
:file:`meta-refkit-core/lib/oeqa/selftest/systemupdate/systemupdatebase.py`
(generic system update testing) and
:file:`meta-refkit-core/lib/oeqa/selftest/cases/refkit_ostree.py`
(usage of that generic class for OSTree and IoT Refkit).

When updating an image manually, the target device must be able to
access the update repository via HTTP. An easy way to make the files
available is via :command:`cd <path>/ostree-repo && python -m
SimpleHTTPServer 8000`. On the target, :file:`/ostree/repo/config`
must be edited so that the URL matches the host running the HTTP
server. How to set up networking so that the target device can reach
the server is out of scope for this document.


Block-Based Update: Undecided
=============================

Mender.io is currently the leading candidate here, mostly because it
is simple to use and comes with a hosted update service. The unsolved
technical challenge at the moment is integrating the A/B partition
switching into a UEFI-based boot process, potentially with Secure Boot
enabled.
