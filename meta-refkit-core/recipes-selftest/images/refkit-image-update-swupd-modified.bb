SUMMARY = "test image for RefkitSwupdUpdateTestDev: refkit-image-common + swupd + modifications"

# RefkitSwupdUpdateTestDev uses this to avoid rebuilding
# refkit-image-update-swupd when running the test multiple
# times.
require refkit-image-update-swupd.bb

DEPLOY_DIR_SWUPD = "${DEPLOY_DIR}/swupd/${MACHINE}/refkit-image-update-swupd"
SWUPD_VERSION_URL = "http://download.example.com/updates/my-distro/milestone/${MACHINE}/refkit-image-update-swupd"
SWUPD_CONTENT_URL = "http://download.example.com/updates/my-distro/builds/${MACHINE}/refkit-image-update-swupd"
