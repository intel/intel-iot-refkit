FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

DEPENDS += "glib-networking"

BBCLASSEXTEND = "native"
