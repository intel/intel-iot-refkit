SUMMARY = "IoT Reference OS Kit Connectivity package groups"
LICENSE = "MIT"
PR = "r1"

inherit packagegroup

# The package group does not make sense without can-utils, so skip it
# if missing.
python () {
    if not oe.types.boolean(d.getVar('HAVE_CAN_UTILS') or '0'):
        raise bb.parse.SkipRecipe('can-utils dependency not available')
}

SUMMARY_${PN} = "IoT Reference OS Kit CAN stack"
RDEPENDS_${PN} = "\
    can-utils \
    can-init-scripts \
    "
