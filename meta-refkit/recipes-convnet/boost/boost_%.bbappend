PACKAGECONFIG += "python"

do_configure_append() {
    sed -i "/using python : 2.7/d" ${WORKDIR}/user-config.jam
}

