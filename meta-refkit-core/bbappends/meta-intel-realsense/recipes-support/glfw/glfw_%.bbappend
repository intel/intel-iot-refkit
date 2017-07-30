REQUIRED_DISTRO_FEATURES_append_df-refkit-config = "x11"
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'refkit-config', 'distro_features_check', '', d)}
