# Check that the current settings are okay for OSTree as system update mechanism.
# This is meant to be added be in the global INHERIT because then errors are
# detected sooner. ostree-image.bbclass also contains a similar check, in case
# that ostree-sanity.bbclass is not active.

addhandler ostree_check_baseconfig
ostree_check_baseconfig[eventmask] = "bb.event.ConfigParsed"
python ostree_check_baseconfig() {
   if oe.utils.all_distro_features(d, "ostree") and \
       not oe.utils.all_distro_features(d, "usrmerge"):
       bb.fatal("The ostree distro feature can only be used in combination with the usrmerge distro feature.")
}
