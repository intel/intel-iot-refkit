This layer defines the distribution of the
IoT Reference OS Kit for Intel(r) Architecture project.


Dependencies
============

The layer depends on various other layers. See the top-level
``.gitmodules`` for details.

Use ``git ls-tree HEAD | grep " commit "`` at the root of the
repository to get a list of the exact revisions of those other layers
that the distribution was tested against.


Patches
=======

See the "Submitting Patches" section in the top-level ``README.rst``.


Adding the refkit layer to your build
=====================================

The intended use of this layer is to check out the entire repository,
including sub-modules, and then setting up a new build directory with
the top-level ``oe-init-build-env`` script.

See the top-level ``README.rst`` for details.
