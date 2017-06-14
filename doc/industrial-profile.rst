Industrial Robotics profile
###########################

Introduction
============

The purpose of the industrial profile is to provide a solid base for
developing robotics applications that can be used for labour automation in
manufacturing, logistics and other domains.

Target audience
===============

The profile is for anybody who is interested in developing such applications
on top of Intel hardware. The main use cases are:

#. Welding/Soldering;
#. Material handling;
#. Dispensing/Coating;
#. Pick and place.

However combined with the computer vision profile they can be extended to
other applications like drones, self-driving cars, agricultural robots etc.

Value proposition
=================

Industrial Robotics profile is made to simplify creation of products using
robotics technologies and is tailored for embedded hardware. Being a part of
Yocto layer it provides full control over build configuration. Unlike
other robotics projects the profile is independent from external binary
package streams.

Key components
==============

So far the `ROS Industrial`_ (ROS-I) project has been identified as a starting
point for the base and this profile includes core packages from the project
and their direct dependencies.

ROS-I is a layer between `ROS`_ (a set of software libraries and tools used
in robot applications) and industrial hardware equipment converting
messages in ROS formats to something understandable by actual hardware.
Although no vendor specific packages are included at the moment.

Currently the profile includes:

- core ROS components,
- libraries for handling geometry and kinematics models of robots in
  the URDF format,
- components from the `MoveIt!`_ framework responsible for a robot's
  joints movement planning,
- core ROS-I components used for interfacing with real robot hardware.

Due to the embedded nature of IoT Refkit no GUI components have been included
in the profile. Users are expected to run ROS GUI nodes (e.g. Rviz) on
their workstations if there's such a need.

For detailed usage instructions please refer `ROS Industrial tutorials`_

The ``meta-refkit-extra`` layer contains example ROS applications and
detailed instructions on how to run them.

.. _ROS Industrial: http://rosindustrial.org
.. _ROS: http://ros.org
.. _MoveIt!: http://moveit.ros.org
.. _ROS Industrial tutorials: http://wiki.ros.org/Industrial/Tutorials
