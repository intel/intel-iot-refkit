FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# Make sure we compile with ca-certificates support enabled.
PACKAGECONFIG_append = " ca-certificates"

DEPENDS += "ca-certificates"
RDEPENDS_${PN} += "ca-certificates"

# We need native version for ostree-/flatpak-native.
BBCLASSEXTEND = "native"

# OE-core's relocatable.bbclass assumes that every package which
# ends up creating a ${libdir}/pkgconfig directory in its sysroot
# will always also install .pc-files there and tries to uncondi-
# tionally update paths in those files using globbing that fails
# if no such files are present. This presumption is not true for
# glib-networking which happens to create a directory by dereferencing
# a GIO pkgconfig variable which in turn is defined relative to
# the pkgconfig directory (${pcfiledir}/../...), causing pkgconfig
# to get created.
#
# Could be worked around in the upatream recipe but since that
# does not provide/create native versions of the package and since
# this problem is related to native packages, we work around it here.
#
do_install_append_class-native () {
    for _pc in ${D}${libdir}/pkgconfig/*.pc; do
        case $_pc in
            *'*.pc') rm -fr ${D}${libdir}/pkgconfig;;
            *.pc)    break;;
        esac
    done
}
