FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI_append_refkit-industrial = "\
    file://0001-Switch-from-TinyXML-to-TinyXML2.patch \
    file://0001-Fixed-inverted-result-code-check.patch \
"
DEPENDS_remove_refkit-industrial = "libtinyxml"
DEPENDS_append_refkit-industrial = " libtinyxml2"
