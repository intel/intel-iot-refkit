FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# Can be removed once https://github.com/ros/ros_comm/pull/1105 is in
# meta-ros.
SRC_URI_append_df-refkit-industrial = " file://roscpp-add-missing-header-for-writev.patch;striplevel=3"
