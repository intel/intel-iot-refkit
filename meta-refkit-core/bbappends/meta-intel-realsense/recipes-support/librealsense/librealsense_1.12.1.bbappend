# History of the git repo was rewritten so that the SRCREV is no longer on the master
# branch...
SRC_URI_remove_df-refkit-config = "git://github.com/IntelRealSense/librealsense.git;branch=master"
SRC_URI_prepend_df-refkit-config = "git://github.com/IntelRealSense/librealsense.git;nobranch=1 "
