FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_df-refkit-computervision = " \
    file://0001-opencv-link-dynamically-against-OpenCL-library.patch \
"

DEPENDS_remove_df-refkit-computervision = "python"
DEPENDS_append_df-refkit-computervision = " python3"

python () {
    if bb.utils.contains('DISTRO_FEATURES', 'refkit-computervision', True, False, d):
        d.setVarFlag('PACKAGECONFIG', 'opencl', '-DWITH_OPENCL=ON,-DWITH_OPENCL=OFF,virtual/opencl-headers virtual/opencl-icd,')
}
