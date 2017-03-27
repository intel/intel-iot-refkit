DEPENDS_remove = "readline gdbm db"

PACKAGECONFIG ??= "readline gdbm db"
PACKAGECONFIG[readline] = ",,readline"
PACKAGECONFIG[gdbm] = ",,gdbm"
PACKAGECONFIG[db] = ",,db"

RRECOMMENDS_${PN}-core = "${@bb.utils.contains('PACKAGECONFIG', 'readline', '${PN}-readline', '', d)}"

# if readline is not there, don't create python3-readline package
PACKAGES_remove += "${@bb.utils.contains('PACKAGECONFIG', 'readline', '', '${PN}-readline', d)}"
PROVIDES_remove += "${@bb.utils.contains('PACKAGECONFIG', 'readline', '', '${PN}-readline', d)}"
RDEPENDS_${PN}-modules_remove += "${@bb.utils.contains('PACKAGECONFIG', 'readline', '', '${PN}-readline', d)}"
