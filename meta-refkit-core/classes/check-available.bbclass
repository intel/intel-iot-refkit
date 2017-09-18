# Use this class in recipes which depend on other recipes
# or classes that might not be available. The class will then
# will skip the current recipe with a suitable explanation.
#
# The expressions that define whether a component is available must
# expand to something that Python considers as False (empty string,
# None, etc.) or one of the values accepted by oe.types.boolean()
# (0/1/True/False/Yes/No).
#
# Example:
#
# DEPENDS = "foobar"
#
# inherit check-available
# CHECK_AVAILABLE[foobar] = "${HAVE_FOOBAR}"
#
# inherit ${@ check_available_class(d, 'meson',  ${HAVE_MESON}) }

def check_available(available):
    if isinstance(available, bool):
        return available
    elif isinstance(available, str) and available != '':
        return oe.types.boolean(available)
    else:
        return bool(available)

def check_available_add_missing(d, component):
    missing = d.getVar('_check_available_missing')
    if missing is None:
        missing = []
    missing.append(component)
    d.setVar('_check_available_missing', missing)

def check_available_class(d, classname, available):
    if check_available(available):
        return classname
    else:
        check_available_add_missing(d, classname + '.bbclass')
        return ''

python () {
    missing = d.getVar('_check_available_missing')
    if missing is None:
        missing = []
    for component in (d.getVarFlags('CHECK_AVAILABLE') or []):
        available = d.getVarFlag('CHECK_AVAILABLE', component)
        try:
            if not check_available(available):
                missing.append(component)
        except ValueError as ex:
            # This typically is a user error, like setting an invalid value.
            # Without additional information about the exact component which
            # fails, the error would be hard to find as "bitbake -e" also just
            # throws the error.
            import sys
            tb = sys.exc_info()[2]
            raise ValueError('evaluating CHECK_AVAILABLE[%s] = %s = %s failed: %s' %
                             (component,
                              d.getVarFlag('CHECK_AVAILABLE', component, False),
                              available,
                              ex)).with_traceback(tb)

    if missing:
        raise bb.parse.SkipRecipe('some required components are unavailable: ' + ', '.join(missing))
}
