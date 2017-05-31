Computer Vision Profile
#######################

Introduction
============

Computer vision is about processing and extracting data from still
images or videos. A classical example is classifying image content by
using a model trained with large amounts of pre-labeled image data. The
use cases are somewhat overlapping with AI and graphics, so computer
vision profile provides also some special support for them.

Target audience
===============

Computer vision profile is meant for anybody who needs to capture still images
or video, process it, and then analyze it in IoT domain. Some example use cases:

#. Security cameras
#. Automated drones and other vehicles
#. Robots
#. Wearables (smart glasses)
#. Industrial vision, quality assurance
#. Home automation
#. Gesture control

Value proposition
=================

Computer vision profile is made to simplify creation of products which
need to employ computer vision technologies. We don't provide any custom
components, but instead we focus our efforts into making sure the
integration of open source components is as seamless as possible.

We especially aim to:

#. Create demos which provide starting points for product development.
#. Make sure the different computer vision components are scriptable with the
   same scripting language, making it possible to create demos and
   proof-of-concepts utilizing different computer vision techniques. We have
   selected Python 3 to be this language. NumPy matrixes are the common format
   for sharing image data between different libraries.
#. Provide hardware acceleration using OpenCL and Intel-specific
   technologies for the components which support them.
#. Select components thoughtfully, keeping in mind their licensing and
   security history. Computer vision profile's production configuration doesn't
   depend on any components which use (L)GPLv3 license, making it easier
   to employ technologies such as Secure Boot.

Key components
==============

`OpenCV <http://opencv.org/>`_ is the backbone of the open source computer
vision software components. We integrate it with some extra configuraton. We add
`gstreamer-vaapi <https://gstreamer.freedesktop.org/modules/gstreamer-vaapi.html>`_
for Intel-accelerated video encoding, decoding, and processing. Intel RealSense
camera support is provided by
`librealsense <https://github.com/IntelRealSense/librealsense>`_.

In addition to this, we add OpenCL hardware acceleration capabilities with
`Beignet <https://www.freedesktop.org/wiki/Software/Beignet/>`_. It can be
accessed using `ViennaCL lineal algebra library <http://viennacl.sourceforge.net/>`_.

Computer vision profile's production configuration contains examples and samples
for OpenCV, librealsense, and OpenCL, allowing users to validate that the
subsystems work and run some benchmarks.

The ``meta-refkit-extra`` layer contains `Caffe deep learning framework
<http://caffe.berkeleyvision.org/>`_, which can be used for image classification
and even training DNN models, though training is slow on IoT devices. The layer
also contains Python 3 bindings for librealsense and some Python 3 image
processing libraries (`ImageIO <https://imageio.github.io/>`_ and `Pillow
<https://python-pillow.org/>`_).
