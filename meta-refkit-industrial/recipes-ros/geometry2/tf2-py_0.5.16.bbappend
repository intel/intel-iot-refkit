FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_df-refkit-config = " \
    file://0001-Use-string-conversion-from-python_compat_h.patch;patchdir=${WORKDIR}/${ROS_SP} \
    file://0002-fix-python3-import-error.patch;patchdir=${WORKDIR}/${ROS_SP} \
"
