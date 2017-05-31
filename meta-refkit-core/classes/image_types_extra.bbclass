# IoT Reference OS Kit custom conversion types

CONVERSIONTYPES_append = " vdi"
CONVERSION_CMD_vdi = "qemu-img convert -O vdi ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.vdi"
CONVERSION_DEPENDS_vdi = "qemu-native"

CONVERSIONTYPES_append = " zip"
ZIP_COMPRESSION_LEVEL ?= "-9"
CONVERSION_CMD_zip = "zip ${ZIP_COMPRESSION_LEVEL} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.zip ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}"
CONVERSION_DEPENDS_zip = "zip-native"
