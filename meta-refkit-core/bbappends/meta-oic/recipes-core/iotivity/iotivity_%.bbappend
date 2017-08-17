# iotivity fails to link with binutils 2.29 that changes -rpath behaviour
# to search under sysroot only so we add the build workdir to cross-linkers
# path with -rpath-link.
#
# Upstream bug reported: https://jira.iotivity.org/browse/IOT-2651

TARGET_LDFLAGS_append_df-refkit-config = " -Wl,-rpath-link=${S}/out/yocto/${IOTIVITY_TARGET_ARCH}/release"
