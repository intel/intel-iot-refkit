do_install_append () {
    # The base recipe sets GROUP=100="users" as shared group for all
    # users. In IoT Reference OS Kit, each user gets its own group (more secure default
    # because it prevents accidental data sharing when setting something
    # group read/writeable).
    sed -i -e 's/^GROUP=/# GROUP=/' ${D}/${sysconfdir}/default/useradd
}
