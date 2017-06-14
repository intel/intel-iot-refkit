DESCRIPTION = "An automatically generated package with all the configuration and launch files for using the uarmmetal with the MoveIt!"
SECTION = "devel"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://package.xml;beginline=11;endline=11;md5=d566ef916e9dedc494f5f793a6690ba5"

SRC_URI = "file://${PN}-${PV}/config/controllers.yaml \
           file://${PN}-${PV}/config/fake_controllers.yaml \
           file://${PN}-${PV}/config/joint_limits.yaml \
           file://${PN}-${PV}/config/kinematics.yaml \
           file://${PN}-${PV}/config/ompl_planning.yaml \
           file://${PN}-${PV}/config/uarmmetal.srdf \
           file://${PN}-${PV}/launch/default_warehouse_db.launch \
           file://${PN}-${PV}/launch/demo.launch \
           file://${PN}-${PV}/launch/fake_moveit_controller_manager.launch.xml \
           file://${PN}-${PV}/launch/joystick_control.launch \
           file://${PN}-${PV}/launch/move_group.launch \
           file://${PN}-${PV}/launch/moveit_planning_execution.launch \
           file://${PN}-${PV}/launch/moveit.rviz \
           file://${PN}-${PV}/launch/moveit_rviz.launch \
           file://${PN}-${PV}/launch/ompl_planning_pipeline.launch.xml \
           file://${PN}-${PV}/launch/planning_context.launch \
           file://${PN}-${PV}/launch/planning_pipeline.launch.xml \
           file://${PN}-${PV}/launch/run_benchmark_ompl.launch \
           file://${PN}-${PV}/launch/sensor_manager.launch.xml \
           file://${PN}-${PV}/launch/setup_assistant.launch \
           file://${PN}-${PV}/launch/trajectory_execution.launch.xml\
           file://${PN}-${PV}/launch/uarmmetal_moveit_controller_manager.launch.xml \
           file://${PN}-${PV}/launch/uarmmetal_moveit_sensor_manager.launch.xml \
           file://${PN}-${PV}/launch/warehouse.launch \
           file://${PN}-${PV}/launch/warehouse_settings.launch.xml \
           file://${PN}-${PV}/CMakeLists.txt \
           file://${PN}-${PV}/package.xml \
           file://${PN}-${PV}/.setup_assistant \
          "

inherit catkin

RDEPENDS_${PN} = "uarmmetal-support robot-state-publisher moveit-ros-move-group roslaunch moveit-planners-ompl moveit-simple-controller-manager moveit-ros-manipulation"
