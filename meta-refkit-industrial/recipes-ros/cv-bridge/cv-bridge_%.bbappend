# TODO: This way cv_bridge doesn't require libboost_python, but this tweak
#       should be dropped after ROS drops compatibility with python2.
EXTRA_OECMAKE_append_df-refkit-industrial = " -DANDROID=ON"
