# groupcheck only looks at auxiliary groups.
# In order to grant root processes access to
# actions that are reserved for administrators,
# "root" must be in the "adm" group.

do_install_append_df-refkit-groupcheck () {
    if grep -q '^adm:.*:$' ${D}${datadir}/base-passwd/group.master; then
        sed -i -e 's/^\(adm:.*:\)$/\1root/' ${D}${datadir}/base-passwd/group.master
    elif grep -q '^adm:.*:\(.*\)$' ${D}${datadir}/base-passwd/group.master; then
        sed -i -e 's/^\(adm:.*:\)\(.*\)$/\1root,\2/' ${D}${datadir}/base-passwd/group.master
    else
        bbfatal "adding root to adm group impossible"
    fi
}
