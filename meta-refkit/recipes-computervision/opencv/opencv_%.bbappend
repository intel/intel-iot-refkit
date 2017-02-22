FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append = " \
    file://0001-opencv-link-dynamically-against-OpenCL-library.patch \
"

PACKAGECONFIG[opencl] = "-DWITH_OPENCL=ON,-DWITH_OPENCL=OFF,virtual/opencl-headers virtual/opencl-icd,"
