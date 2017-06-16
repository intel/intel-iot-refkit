Introduction
============

The core of the ROS project is a XMLRPC-based publisher-subscriber
middleware. This instruction documents how to run a simple ROS
application in IoT Refkit. The application is documented in
the `Writing a Simple Publisher and Subscriber`_ tutorial.

How to run
==========

1. Create an image containing the package `refkit-ros-tests`, e.g. by putting
   this line in your `local.conf`::

     IMAGE_INSTALL_append = " refkit-ros-tests"

   and running::

     $ bitbake refkit-image-common

2. Start up a QEMU VM with the built image::

     $ runqemu ovmf refkit-image-common wic slirp serial nographic

3. Set up ROS environment in the VM::

     export ROS_ROOT=/opt/ros
     export ROS_DISTRO=indigo
     export ROS_PACKAGE_PATH=/opt/ros/indigo/share
     export PATH=$PATH:/opt/ros/indigo/bin
     export LD_LIBRARY_PATH=/opt/ros/indigo/lib
     export PYTHONPATH=/opt/ros/indigo/lib/python3.5/site-packages
     export ROS_MASTER_URI=http://localhost:11311
     export CMAKE_PREFIX_PATH=/opt/ros/indigo
     touch /opt/ros/indigo/.catkin

4. Launch all the needed ROS nodes with the command::

     roslaunch refkit_ros_tests helloworld.launch

If everything is correct then two nodes get launched:

- a publisher node sending standard string messages "hello world" to a ROS
  topic and
- a subscriber node listening to the topic and exiting upon the
  message.

As soon as the subscriber node exits all the other nodes should
exit successfully.

.. _Writing a Simple Publisher and Subscriber: http://wiki.ros.org/ROS/Tutorials/WritingPublisherSubscriber%28python%29
