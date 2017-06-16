# Same as systemd.bbclass but should be used by recipes which require
# systemd (as opposed to just support systemd).


SYSTEMD_FEATURE_class-target = "systemd"
SYSTEMD_FEATURE_class-native = ""

REQUIRED_DISTRO_FEATURES = "${SYSTEMD_FEATURE}"
inherit distro_features_check

inherit systemd
