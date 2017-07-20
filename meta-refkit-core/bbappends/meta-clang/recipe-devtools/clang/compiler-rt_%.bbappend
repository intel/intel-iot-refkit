FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# This fixes https://github.com/google/sanitizers/issues/822, a build
# breakage caused by changes in glibc 2.25.90. The fix should already
# be in the version used by upstream meta-clang, but we cannot update
# refkit to that because beignet-native does not build with meta-clang
# master ("use of type '__write_only image3d_t' requires
# cl_khr_3d_image_writes extension to be enabled").
#
# However, the upstream commit was also incomplete.
SRC_URI_append_df-refkit-config = " \
    file://Fix-sanitizer-build-against-latest-glibc.patch \
    file://Fix-sanitizer-build-against-latest-glibc-missing-hunk.patch \
"
