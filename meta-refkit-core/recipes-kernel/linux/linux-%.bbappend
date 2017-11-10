# Typically, generic BSPs do not enable special features that are
# needed only by some distros. For example, TPM, dm-verity and
# nf-tables are disabled in meta-intel BSPs.
#
# But refkit wants certain kernel features enabled depending on distro
# features. Expecting the developer to know about this and then make
# changes to the BSP he is using is not very developer-friendly and
# also makes automated testing in the CI harder.
#
# Therefore we use this .bbappend to reconfigure all kernel recipes
# called linux-<something>. Using a .bbappend instead of manipulating
# SRC_URI in refkit-config.inc is a performance tweak: this way
# we avoid touching the SRC_URI of all recipes. The same code would
# also work in global scope.
#
# Reconfiguring works for kernel recipes that support kernel config
# fragments. If the default is undesired, then override or modify
# REFKIT_KERNEL_SRC_URI for the kernel recipe(s) that this bbappend is
# not meant to modify.
REFKIT_KERNEL_SRC_URI ??= "${@ refkit_kernel_config(d) }"

# The refkit distro cannot make assumptions about which features are
# available in the kernel recipe that we are modifying here.
# Therefore we have our own feature definitions.
#
# For a full discussion of this topic see:
# https://bugzilla.yoctoproject.org/show_bug.cgi?id=8191
FILESEXTRAPATHS_prepend := "${THISDIR}/refkit-kernel-cache:"

# Both .scc and .cfg files are listed here to ensure that the kernel
# gets recompiled when any of them change.
def refkit_kernel_config(d):
    # This maps distro features to the corresponding feature definition file(s).
    distro2config = {
        'dm-verity': 'dm-verity.scc dm-verity.cfg',
        'tpm': 'tpm.scc tpm.cfg',
        'tpm2': 'tpm2.scc tpm2.cfg',
        'refkit-firewall': 'nf_tables.scc nf_tables.cfg',
    }
    uris = []
    for feature in d.getVar('DISTRO_FEATURES').split():
        config = distro2config.get(feature, None)
        if config:
            uris.extend(['file://' + x for x in config.split()])
    return ' '.join(uris)

SRC_URI_append_df-refkit-config = " \
    ${@ d.getVar('REFKIT_KERNEL_SRC_URI') if \
        bb.data.inherits_class('kernel', d) \
        else '' } \
"
