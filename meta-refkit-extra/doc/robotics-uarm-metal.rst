Introduction
============

This is a detailed walkthrough on how to configure MoveIt! framework to
control an uArm Metal mechanical arm. All the needed config files
are provided by this layer.

Prerequisites
=============

Your uArm Metal's controller must be programmed to support a small subset
of G-codes sent via its serial. Particularly it needs to understand the codes:

M203
   Attach all servos.

M204
   Detach all servos.

G205 <base_angle> <left_angle> <right_angle> <hand_angle>
   Set position for all four servos. The code accepts four parameters which
   are PWM signal widths for the respective servos in microseconds.

P200
   Return current servo positions as raw data from the servos' analog pins.
   The command should reply with a line like::

     RET <base_analog_angle> <left_analog_angle> <right_analog_angle> <hand_analog_angle>

As soon as the controller is ready to receive a new G-code it must signal that
by sending `ok` to serial.

Setting up
==========

1. Create an image containing the packages `uarmmeta-moveit-config`,
   `python3-pyserial` and `python3-asyncio`, e.g. by putting this line
   in your `local.conf`::

     IMAGE_INSTALL_append = " uarmmeta-moveit-config python3-pyserial python3-asyncio"

   and running::

     $ bitbake refkit-image-common

2. Install the image onto your device. See the howto "Installing the Images"
   in IoT Reference OS Kit documentation for details.

3. Plug the mechanical arm in the device's USB port.

4. Run the following script on the device.

.. code:: python

   #!/usr/bin/env python3
   """
   TCP robot controller implementing streaming Joint Position Streaming Interface
   for uARM Metal.

   The controller acts as a server for all connections and manages
   the mechanical arm through a serial connection.

   See http://wiki.ros.org/Industrial/Tutorials/create_joint_position_streaming_interface_using_tcp_socket_libraries.
   """

   import asyncio
   import struct
   import math

   import serial

   # Analog signal for servos' null positions
   BASE_ANALOG_NULL = 350
   LEFT_ANALOG_NULL = 145
   RIGHT_ANALOG_NULL = 137
   HAND_ANALOG_NULL = 282

   # 1 unit of analog signal in radians
   BASE_ANALOG_RAD = math.pi/(3.111111111*180)
   LEFT_ANALOG_RAD = math.pi/(2.811111111*180)
   RIGHT_ANALOG_RAD = math.pi/(2.655555555*180)

   # 1 PWM microsecond in analog signal units
   BASE_PWM_ANALOG = 0.281
   LEFT_PWM_ANALOG = 0.280
   RIGHT_PWM_ANALOG = 0.275

   # Zero positions in PWM microseconds
   BASE_ZERO_PWM = 1500
   LEFT_ZERO_PWM = 750
   RIGHT_ZERO_PWM = 700
   HAND_ZERO_PWM = 1500

   class RobotArm(object):
       """Represent the mechanical arm."""

       def __init__(self, loop):
           """Initialize object."""

           self.is_inited = False
           self.transport = None
           self.loop = loop
           self.serial_lock = asyncio.Lock(loop=loop)
           self.move_lock = asyncio.Lock(loop=loop)
           self.serial = serial.Serial("/dev/ttyUSB0", 115200, timeout=5)
           loop.add_reader(self.serial, self.__serial_reader)

       @asyncio.coroutine
       def __initialize(self):
           """Initialize robot arm."""

           self.is_inited = True
           yield from self.__send_to_robot(b"M203\n")
           yield from self.__send_to_robot(b"G205 1500 1300 1300 1500\n")

       def __serial_reader(self):
           line = self.serial.readline()

           if line == b"ok\r\n":
               if self.is_inited:
                   self.serial_lock.release()
               else:
                   self.loop.create_task(self.__initialize())
           elif line.startswith(b"RET") and not self.transport.is_closing():
               (j1, j2, j3, _) = (int(analog_signal)
                                  for analog_signal in line[4:].split())
               base_link_to_base_rot = (j1 - BASE_ANALOG_NULL) * BASE_ANALOG_RAD
               base_rot_to_link_1 = (j2 - LEFT_ANALOG_NULL) * LEFT_ANALOG_RAD
               link_2_to_link_3 = (j3 - RIGHT_ANALOG_NULL) * RIGHT_ANALOG_RAD
               link_1_to_link_2 = -base_rot_to_link_1 - link_2_to_link_3
               link_3_to_link_end = 0
               message = struct.pack("<Iiiiiffffffffff", 56, 10, 1, 0, 0,
                                     base_link_to_base_rot,
                                     base_rot_to_link_1,
                                     link_1_to_link_2,
                                     link_2_to_link_3,
                                     link_3_to_link_end,
                                     0.0, 0.0, 0.0, 0.0, 0.0)
               self.transport.write(message)
           elif line.startswith(b"ERROR"):
               print("Got from robot: %s" % line)

       @asyncio.coroutine
       def __send_to_robot(self, command):
           yield from self.serial_lock
           self.serial.write(command)

       @asyncio.coroutine
       def __periodic_p200(self):
           while not self.transport.is_closing():
               if self.is_inited:
                   yield from self.__send_to_robot(b"P200\n")
               yield from asyncio.sleep(0.1)
           self.transport = None

       def deinit(self):
           """Gracefully deinitialize robot arm."""

           self.loop.run_until_complete(self.__send_to_robot(b"M204\n"))
           self.serial.close()

       def stream_joint_state(self, transport):
           """Start streaming arm's current state to TCP transport."""

           self.transport = transport
           asyncio.ensure_future(self.__periodic_p200(), loop=self.loop)

       @asyncio.coroutine
       def move_servos(self, base_angle, left_angle, right_angle, hand_angle,
                       duration):
           """Move arm's servos to given angles."""

           base_pwm = int(base_angle / (BASE_ANALOG_RAD * BASE_PWM_ANALOG) +
                          BASE_ZERO_PWM)
           left_pwm = int(left_angle / (LEFT_ANALOG_RAD * LEFT_PWM_ANALOG) +
                          LEFT_ZERO_PWM)
           right_pwm = int(right_angle / (RIGHT_ANALOG_RAD * RIGHT_PWM_ANALOG) +
                           RIGHT_ZERO_PWM)
           hand_pwm = HAND_ZERO_PWM
           message = b"G205 %d %d %d %d\n" % (base_pwm, left_pwm,
                                              right_pwm, hand_pwm)
           with (yield from self.move_lock):
               print(message[:-1])
               yield from self.__send_to_robot(message)
               yield from asyncio.sleep(duration)

   class JointPositionStreamProtocol(asyncio.Protocol):
       """Implements joint position streamming protocol."""

       def __init__(self, loop, robot):

           self.loop = loop
           self.robot = robot
           self.transport = None

       def connection_made(self, transport):

           self.transport = transport

       def data_received(self, data):

           (length,
            msg_id,
            comm_type,
            reply_type,
            seq_num) = struct.unpack("<Iiiii", data[:20])
           assert msg_id == 11, "MSG_ID is not JOINT_TRAJ_PT"
           assert comm_type == 2, "COMM_TYPE is not REQUEST"
           assert reply_type == 0, "REPLY_TYPE is bogus"
           assert len(data) == (length + 4), "LENGTH is bogus"
           unpacked = struct.unpack("<ffffffffffff", data[20:])
           response = struct.pack("<Iiiiiffffffffffff", 64, 11, 3, 1, 0,
                                  0.0, 0.0, 0.0, 0.0, 0.0,
                                  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
           self.transport.write(response)
           print("SEQ_NUM: %s %s" % (seq_num, unpacked))
           if seq_num > 0:
               self.loop.create_task(self.robot.move_servos(unpacked[0],
                                                            unpacked[1],
                                                            unpacked[3],
                                                            unpacked[4],
                                                            unpacked[11]))

   class JointStateStreamProtocol(asyncio.Protocol):
       """Implements joint states streaming protocol."""

       def __init__(self, loop, robot):
           self.loop = loop
           self.robot = robot

       def connection_made(self, transport):
           print("A client connected to Joint State Stream")
           self.robot.stream_joint_state(transport)

   def main():
       """Entry point."""

       loop = asyncio.get_event_loop()
       robotarm = RobotArm(loop)

       proto_factory = lambda: JointPositionStreamProtocol(loop, robotarm)
       joint_pos_coro = loop.create_server(proto_factory, '0.0.0.0', 11000)

       proto_factory = lambda: JointStateStreamProtocol(loop, robotarm)
       joint_state_coro = loop.create_server(proto_factory, '0.0.0.0', 11002)

       joint_pos_server = loop.run_until_complete(joint_pos_coro)
       joint_state_server = loop.run_until_complete(joint_state_coro)

       # Serve requests until Ctrl+C is pressed
       print('Serving on {}'.format(joint_pos_server.sockets[0].getsockname()))
       print('Serving on {}'.format(joint_state_server.sockets[0].getsockname()))
       try:
           loop.run_forever()
       except KeyboardInterrupt:
           pass

       # Close the server
       joint_pos_server.close()
       joint_state_server.close()
       loop.run_until_complete(asyncio.gather(joint_pos_server.wait_closed(),
                                              joint_state_server.wait_closed()))
       robotarm.deinit()
       loop.close()

   if __name__ == "__main__":
       main()

5. Set up ROS environment on the device::

     export ROS_ROOT=/opt/ros
     export ROS_DISTRO=indigo
     export ROS_PACKAGE_PATH=/opt/ros/indigo/share
     export PATH=$PATH:/opt/ros/indigo/bin
     export LD_LIBRARY_PATH=/opt/ros/indigo/lib
     export PYTHONPATH=/opt/ros/indigo/lib/python3.5/site-packages
     export ROS_MASTER_URI=http://localhost:11311
     export CMAKE_PREFIX_PATH=/opt/ros/indigo
     touch /opt/ros/indigo/.catkin

6. Launch all the needed ROS nodes with the command::

     roslaunch uarmmetal_support refkit-uarm.launch robot_ip:=127.0.0.1 sim:=false

Now your mechanical arm can be controlled through MoveIt's Move Group Interface.
It's possible to control the arm interactively  with a GUI ROS node installed
on your desktop (i.e. `RViz`_). For that copy the source code of the packages
`uarmmetal-support` and `uarmmetal-moveit-configs` to your `catkin workspace`_
on the desktop as `uarmmetal_support` and `uarmmetal_moveit_configs` ROS packages
respectively. First initialize ROS environment::

  source <path_to_your_catkin_workspace>/devel/setup.bash

Then run::

  ROS_MASTER_URI=http://<your_device_address>:11311 roslaunch uarmmetal_moveit_config moveit_rviz.launch config:=true

.. _RViz: http://wiki.ros.org/rviz/UserGuide
.. _catkin workspace: http://wiki.ros.org/catkin/workspaces
