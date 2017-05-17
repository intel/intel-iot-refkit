# Turns certain DISTRO_FEATURES into overrides of the same name
# or (optionally) some other name. Ensures that these special
# distro features remain set also for native and nativesdk
# recipes, so that these overrides can also be used there.
#
# This makes it simpler to write .bbappends that only change the
# task signatures of the recipe if the change is really enabled,
# for example with:
#   do_install_append_foobar () { ... }
# where "foobar" is an optional DISTRO_FEATURE.
#
# TODO: is renaming useful? It makes the code more complex and potentially slower (untested).

DISTROFEATURES2OVERRIDES ?= ""
DISTROFEATURES2OVERRIDES[doc] = "A space-separated list of <feature>[=<override>] entries. \
Each entry is added to DISTROOVERRIDES with the <feature> name or the optional <override> name, \
but only when <feature> is in DISTRO_FEATURES."

DISTROOVERRIDES_FEATURES = "${@ ' '.join([x.split('=', 1)[0] for x in d.getVar('DISTROFEATURES2OVERRIDES').split()]) }"
DISTRO_FEATURES_FILTER_NATIVE_append = " ${DISTROOVERRIDES_FEATURES}"
DISTRO_FEATURES_FILTER_NATIVESDK_append = " ${DISTROOVERRIDES_FEATURES}"

DISTROOVERRIDES .= "${@ ''.join([':' + (x.split('=')[1] if '=' in x else x) for x in d.getVar('DISTROFEATURES2OVERRIDES').split() if bb.utils.contains('DISTRO_FEATURES', x.split('=', 1)[0], True, False, d)]) }"
