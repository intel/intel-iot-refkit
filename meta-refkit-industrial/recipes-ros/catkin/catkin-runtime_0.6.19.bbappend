FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_df-refkit-industrial = "\
            file://0001-avoid-interfering-with-bitbake-s-LD_LIBRARY_PATH-mod.patch \
            "
