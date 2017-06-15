# Same as systemd.bbclass but should be used by recipes which require
# systemd (as opposed to just support systemd).

REQUIRED_DISTRO_FEATURES = "systemd"
inherit distro_features_check

inherit systemd.bbclass
