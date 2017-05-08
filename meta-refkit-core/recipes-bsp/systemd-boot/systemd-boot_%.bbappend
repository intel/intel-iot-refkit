do_compile_append() {
	oe_runmake linux${SYSTEMD_BOOT_EFI_ARCH}.efi.stub
}

do_deploy_append () {
	install ${B}/linux*.efi.stub ${DEPLOYDIR}
}
