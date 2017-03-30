FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append = " \
    file://0001-Documentation-Intel-SR300-Depth-camera-INZI-format.patch \
    file://0002-uvcvideo-Add-support-for-Intel-SR300-depth-camera.patch \
"
