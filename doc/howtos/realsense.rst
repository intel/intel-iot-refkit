Intel® RealSense™ cameras in IoT Reference OS Kit
#################################################

Intel® RealSense™ cameras are supported in IoT Reference OS Kit using
`librealsense <https://github.com/IntelRealSense/librealsense/>`_
library.  By default ``librealsense`` is installed into the computer
vision profile.

Separation of graphical and console examples
============================================

IoT Reference OS Kit doesn't come with a graphical environment. For this
reason only the console ``librealsense`` examples are available in
computer vision development builds. To test that a camera works
properly, plug it into a powered USB3 hub and enter ``cpp-headless`` to
capture frames using the various channels that the camera supports. The
captured data is saved as ``.png`` files to the current working
directory.

Creating librealsense applications
==================================

Refer to `librealsense documentation
<https://github.com/IntelRealSense/librealsense/blob/master/readme.md>`_
for tutorials and API documentation.

Known issues and limitations
============================

* `pyrealsense <https://github.com/toinsson/pyrealsense>`_ is not yet
  integrated.
* V4L2 API doesn't fully work due to missing support for certain pixel
  color formats.
* No support for SR300 RealSense camera yet.

