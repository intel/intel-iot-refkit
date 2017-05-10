# To be inherited in a bmap-tools_%.bbappend if desired.
# Based on the bmap-tools recipe in Ostro OS XT.
# TODO (?): add to OE-core.

inherit deploy

do_deploy[sstate-outputdirs] = "${DEPLOY_DIR_TOOLS}"
do_deploy[stamp-extra-info] = ""
do_deploy[dirs] = "${S}"
do_deploy_class-native() {
    cp bmaptool __main__.py
    python -m zipfile -c bmaptool.zip bmaptools __main__.py
    echo '#!/usr/bin/env python' | cat - bmaptool.zip > bmaptool-standalone
    install -d ${DEPLOYDIR}
    install -m 0755 bmaptool-standalone ${DEPLOYDIR}/bmaptool-${PV}
    rm -f ${DEPLOYDIR}/bmaptool
    ln -sf ./bmaptool-${PV} ${DEPLOYDIR}/bmaptool
}

do_deploy() {
        :
}

addtask deploy before do_package after do_install
