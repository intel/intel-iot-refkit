require refkit-python.inc

# This is a temporary solution until OE-core upstream supports alternatives for python
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'refkit-config', 'update-alternatives', '', d)}
ALTERNATIVE_PRIORITY_df-refkit-config_class-target = "100"
ALTERNATIVE_${PN}-core_df-refkit-config_class-target = "python python_config"

python () {
    if bb.utils.contains('DISTRO_FEATURES', 'refkit-config', True, False, d) and not d.getVar('PN').startswith('nativesdk-'):
         d.setVarFlag('ALTERNATIVE_LINK_NAME', 'python', d.getVar('bindir') + '/python')
         d.setVarFlag('ALTERNATIVE_LINK_NAME', 'python_config', d.getVar('bindir') + '/python-config')
}
