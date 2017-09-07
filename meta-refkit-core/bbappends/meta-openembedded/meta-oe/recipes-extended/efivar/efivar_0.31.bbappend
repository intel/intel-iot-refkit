do_compile_class-native_df-refkit-config() {
    oe_runmake -C src makeguids
}

do_install_class-native_df-refkit-config() {
    install -D -m 0755 ${B}/src/makeguids ${D}${bindir}/makeguids
}
