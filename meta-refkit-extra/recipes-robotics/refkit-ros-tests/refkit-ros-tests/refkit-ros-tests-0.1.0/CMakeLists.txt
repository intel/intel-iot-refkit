cmake_minimum_required(VERSION 2.8.3)
project(refkit_ros_tests)

find_package(catkin REQUIRED)

catkin_package()

install(DIRECTORY launch
        DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION})
install(PROGRAMS scripts/talker.py
                 scripts/listener.py
        DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION})
