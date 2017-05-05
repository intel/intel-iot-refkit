# i18n only enabled for the target, doesn't build for native
# and isn't needed there.
disable_i18n() {
       sed -i -e 's/^I18N=1/# I18N=1/' ${S}/config.make
}
disable_i18n_class-target () {
  :
}

do_configure_append () {
        disable_i18n
}

BBCLASSEXTEND_append_pn-net-tools = " native nativesdk"
