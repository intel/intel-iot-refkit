# In IoT Reference OS Kit We only put mostly static values into the os-release
# package. That avoids unnecessary recompilations.  Dynamic values
# like BUILD_ID (includes ${DATETIME}) get patched to the current values in
# refkit-image.bbclass.

BUILD_ID_df-refkit-config = "build-id-to-be-added-during-image-creation"
OS_RELEASE_FIELDS_append_df-refkit-config = " BUILD_ID"
