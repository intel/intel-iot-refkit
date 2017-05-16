# Inherits image-mode.bbclass and in addition, creates one variant of the
# current recipe for each valid image mode. The variants have the name
# <base recipe>-<image mode>. Because it is uncertain what is needed,
# everything gets excluded from a world build.

BBCLASSEXTEND += "${@ ' '.join(['image-mode:' + x for x in (d.getVar('IMAGE_MODE_VALID') or '').split()]) }"

python image_mode_virtclass_handler () {
    pn = e.data.getVar("PN", True)
    cls = e.data.getVar("BBEXTENDCURR", True)
    variant = e.data.getVar("BBEXTENDVARIANT", True)
    # multilib.bbclass checks with "if ... return" for historic
    # reasons. Since OE-core 2.0, we are guaranteed to get called only
    # when these values are set, unless the user made a mistake.
    if cls != 'image-mode':
        return
    if not variant:
        bb.fatal('BBCLASSEXTEND=image-mode must be used with parameters, as in BBCLASSEXTEND=image-mode:development')

    # Rename the virtual recipe to create the desired image variant.
    pn = pn + '-' + variant
    e.data.setVar("PN", pn)

    # Set the desired image mode and update the SUMMARY accordingly.
    e.data.setVar("IMAGE_MODE", variant)
    summary = e.data.getVar("SUMMARY")
    if summary.endswith('.'):
        summary += " %s mode." % variant
    else:
        summary += ", %s mode" % variant
}

addhandler image_mode_virtclass_handler
image_mode_virtclass_handler[eventmask] = "bb.event.RecipePreFinalise"
