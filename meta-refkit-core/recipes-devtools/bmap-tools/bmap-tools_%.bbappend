inherit ${@bb.utils.contains('DISTRO_FEATURES', 'refkit-config', 'bmap-tools-deploy', '', d)}
