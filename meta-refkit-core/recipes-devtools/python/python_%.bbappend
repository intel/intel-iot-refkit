require refkit-python.inc

# This is a temporary solution until OE-core upstream supports alternatives for python
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'refkit-config', 'update-alternatives', '', d)}
ALTERNATIVE_PRIORITY_refkit-config = "100"
ALTERNATIVE_${PN}-core_refkit-config = "python python_config"

python () {
    if bb.utils.contains('DISTRO_FEATURES', 'refkit-config', True, False, d):
         d.setVarFlag('ALTERNATIVE_LINK_NAME', 'python', d.getVar('bindir') + '/python')
         d.setVarFlag('ALTERNATIVE_LINK_NAME', 'python_config', d.getVar('bindir') + '/python-config')
}
