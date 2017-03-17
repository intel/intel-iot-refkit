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

Profile implementation and usage
================================

The profiles are buildable image targets and are implemented by image recipes.
Each profile belongs to the same distribution that consequently means that the distribution-wide
settings are shared. Therefore, DISTRO_FEATURES cannot be added to profiles without
them affecting also the other profiles.

Furthermore, the kernel configuration is shared between the profiles, meaning that profiles
contain kernel features which are not necessarily needed in the profile.
The users of the profiles should verify the kernel configuration and only add
the kernel features that are needed for their own particular use case.

The profiles (``refkit-image-<profilename>``) have the high-level
tools and frameworks installed for several possible tools that make sense for
the profile. The users need to see which ones they really need and remove the
other tools from the image. Probably the best way to accomplish this is to copy
the image recipe with a custom name and do the required changes there.

When building the "development" versions of the profiles (``refkit-development.inc`` included),
additional components to support testing are installed. For each profile, the testing specific content
is provided by ``<profilename>-test`` image feature. This content is not installed when building
the "production" versions (``refkit-production.inc`` included).

The goal is to keep the custom profile content minimal. All changes should be
upstreamed whenever possible.

Profile Summary
===============

#. refkit-image-minimal: The minimal configuration that boots on a device.
#. refkit-image-common: A configuration with interactive tools but without any special software in it. Recommended target if you are not interested in any given profile.
#. refkit-image-computervision: A profile with tools and configuration for computer vision use cases.
#. refkit-image-gateway: A profile with tools and configuration for acting as an IoT sensor.
