SRC_URI_append_df-refkit-config = " https://git.kernel.org/pub/scm/linux/kernel/git/iwlwifi/linux-firmware.git/plain/iwlwifi-8000C-31.ucode;name=iwlwifi-backport-31"

SRC_URI[iwlwifi-backport-31.md5sum] = "428a84a780bbe864a7af6a6734c4b529"
SRC_URI[iwlwifi-backport-31.sha256sum] = "5a337c52f9d7a7cb5cb0a13c93232f4de742ed0debef757d68231bdb55455406"

do_install_append_df-refkit-config() {
    # Copy the iwlwifi-backport ucode
    cp ${WORKDIR}/iwlwifi-8000C-31.ucode ${D}/${nonarch_base_libdir}/firmware/
}
