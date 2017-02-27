FILESEXTRAPATHS_prepend := "${THISDIR}/systemd-boot:"

SRC_URI_append_intel-x86-common = " \
            file://0001-sd-boot-support-global-kernel-command-line-in-EFI-st.patch \
            file://0001-sd-boot-stub-check-LoadOptions-contains-data.patch \
            "
SRC_URI_remove_intel-x86-common = "file://0004-sd-boot-Support-global-kernel-command-line-fragment-in-EFI-stub.patch"

do_compile_append() {
	oe_runmake linux${SYSTEMD_BOOT_EFI_ARCH}.efi.stub
}

do_deploy_append () {
	install ${B}/linux*.efi.stub ${DEPLOYDIR}
}
