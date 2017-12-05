# Workaround for https://github.com/intel/tpm2-tss/issues/613
CFLAGS_append_df-refkit-config = " -Wno-error=int-in-bool-context"
CXXFLAGS_append_df-refkit-config = " -Wno-error=int-in-bool-context"
