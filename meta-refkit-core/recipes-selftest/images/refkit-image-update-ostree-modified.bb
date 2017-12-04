SUMMARY = "test image for RefkitOSTreeUpdateTest: refkit-image-common + OSTree + modifications"

# RefkitOSTreeUpdateTestDev uses this to avoid rebuilding
# refkit-image-update-ostree-modified when running the test multiple
# times.
require refkit-image-update-ostree.bb
OSTREE_BRANCHNAME = "${DISTRO}/${MACHINE}/refkit-image-update-ostree"
