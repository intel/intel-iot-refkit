# Turns certain refkit DISTRO_FEATURES into overrides of the same name.
# This makes it simpler to write .bbappends that only change the
# task signatures of the recipe if the change is really enabled,
# for example with:
# do_install_append_refkit-firewall () { ... }
DISTROFEATURES2OVERRIDES += " \
    refkit-config \
    refkit-firewall \
    refkit-computervision \
    refkit-gateway \
"

INHERIT += "distrooverrides"
