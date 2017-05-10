# Config helper .bbclass for refkit-config.inc.
# We have to delay setting these variables until
# we have the final DISTRO_FEATURES.

python () {
    features = d.getVar('DISTRO_FEATURES').split()
    if 'systemd' in features and 'refkit-config' in features:
        d.setVar('VIRTUAL-RUNTIME_init_manager', 'systemd')
        d.setVar('VIRTUAL-RUNTIME_initscripts', '')
}

