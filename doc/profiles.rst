IoT Reference OS Kit Profiles
#############################

Introduction
============

IoT Reference OS Kit for Intel(r) Architecture maintains a set of pre-configured
image configurations that demonstrate certain key IoT usages. These image
configurations are called profiles.

A profile means two things:

#. Image configuration for basing future work on towards a certain use case
#. Image configuration for demonstrating and testing the features for a use case

These goals are somewhat separate: the first case is meant as a baseline for
creating an image with custom code. It should already have available the
required recipes and proper image configuration, thus making the initial steps
easier.

The basic principles of a profile configuration are:

#. the configuration is minimal/clean and does not pull in excess content
#. the configuration is easy to customize
#. the configuration is documented

This purpose of this document is to document each profile/configuration. The list is also
maintained in `conf-notes.txt` and shown every time the build target is being prepared.

Profile implementation
======================

Profiles are buildable image targets. Every profile offers two targets: one as a
basis for further development (``refkit-image-<profilename>``) and one as a
means for testing and experimenting with the profile
(``refkit-image-<profilename>-test``). The test image should be easily usable
and contain various tools for trying out the profile features.

Because the profiles are implemented as recipes, they all belong to the same
distribution. This means that the distribution-wide settings are shared between
the profiles, meaning that DISTRO_FEATURES cannot be added to profiles without
them affecting also the other profiles.

The goal is to keep the custom profile content minimal. All changes should be
upstreamed whenever possible.

Taking a profile into use
=========================

The kernel configuration is shared between the profiles, meaning that profiles
do contain kernel features which are not necessarily needed in the profile.
The users of the profiles should verify the kernel configuration and only add
the kernel features that are needed for their own particular use case.

The development images (``refkit-image-<profilename>``) have the high-level
tools and frameworks installed for several possible tools that make sense for
the profile. The users need to see which ones they really need and remove the
other tools from the image. Probably the best way to accomplish this is to copy
the image recipe with a custom name and do the required changes there.

Profile Summary
===============

#. refkit-image-minimal: The minimal configuration that boots on a device.
#. refkit-image-common: A configuration with interactive tools but without any special software in it. Recommended target if you are not interested in any given profile.
#. refkit-image-computervision: A profile with tools and configuration for computer vision use cases.
#. refkit-image-gateway: A profile with tools and configuration for acting as an IoT sensor.
