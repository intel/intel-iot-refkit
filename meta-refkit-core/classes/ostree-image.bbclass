# Support for OSTree-upgradable images.
#
# This class adds support for building images with OSTree system
# update support. It is an addendum to refkit-image.bbclass (i.e.
# not tested with anything else) and is supposed to be inherited
# by it conditionally when the "ostree" distro feature is set.
#
# When enabled both in the distro and image, the class adds:
#
#     - publishing builds to an HTTP-serviceable repository
#     - boot-time selection of the most recent rootfs tree
#     - booting an OSTree enabled image into a rootfs
#     - pulling in image upgrades using OSTree
#
###########################################################################

# Declare an image feature for OSTree-upgradeable images.
# OSTree support in the image is still off unless that
# feature gets selected elsewhere.
IMAGE_FEATURES[validitems] += " \
    ostree \
"

# rekit-ostree RDEPENDS on ostree, so we don't need to list that here.
FEATURE_PACKAGES_ostree = " \
    refkit-ostree \
"

# Additional sanity checking. Complements ostree-sanity in INHERIT.
REQUIRED_DISTRO_FEATURES += "ostree usrmerge"
inherit distro_features_check

###########################################################################

# These are intermediate working directories that are not meant to
# be overridden:
# - build content as it gets committed to the OSTree repos
# - intermediate, bare OSTree repo
# - rootfs with OSTree set up
OSTREE_SYSROOT = "${WORKDIR}/ostree-sysroot"
OSTREE_BARE = "${WORKDIR}/ostree-repo"
OSTREE_ROOTFS = "${IMAGE_ROOTFS}.ostree"

# OS deployment name on the target device.
OSTREE_OS ?= "${DISTRO}"

# Each image is committed to its own, unique branch.
OSTREE_BRANCHNAME ?= "${DISTRO}/${MACHINE}/${PN}"

# The subject of the commit that gets added to OSTREE_BRANCHNAME for
# the current build.
OSTREE_COMMIT_SUBJECT ?= 'Build ${BUILD_ID} of ${PN} in ${DISTRO}'

# This is where we export our builds in archive-z2 format. This repository
# can be exposed over HTTP for clients to pull upgrades from. It can be
# shared between different distributions, architectures and images
# because each image has its own branch in the common repository.
#
# Beware that this repo is under TMPDIR by default. Just like other
# build output it should be moved to a permanent location if it
# is meant to be preserved after a successful build (for example,
# with "ostree pull-local" in a permanent repo), or the variable
# needs to point towards an external directory which exists
# across builds.
#
# This can be set to an empty string to disable publishing.
OSTREE_REPO ?= "${DEPLOY_DIR}/ostree-repo"

# OSTREE_GPGDIR is where our GPG keyring is located at and
# OSTREE_GPGID is the default key ID we use to sign (commits in) the
# repository. These two need to be customized for real builds.
#
# In development images the default is to use a pregenerated key from
# an in-repo keyring. Production images do not have a default.
#
OSTREE_GPGDIR ?= "${@ '' if (d.getVar('IMAGE_MODE') or 'production') == 'production' else '${META_REFKIT_CORE_BASE}/files/gnupg' }"
OSTREE_GPGID_DEFAULT = "${@d.getVar('DISTRO').replace(' ', '_') + '-development-signing@key'}"
OSTREE_GPGID ?= "${@ '' if (d.getVar('IMAGE_MODE') or 'production') == 'production' else '${OSTREE_GPGID_DEFAULT}' }"

python () {
    if bb.utils.contains('IMAGE_FEATURES', 'ostree', True, False, d) and \
       not d.getVar('OSTREE_GPGID'):
        raise bb.parse.SkipRecipe('OSTREE_GPGID not set')
}

# OSTree remote (HTTP URL) where updates will be published.
# Host the content of OSTREE_REPO there.
OSTREE_REMOTE ?= "https://update.example.org/ostree/"

# These variables are read by OSTreeUpdate and thus contribute to the vardeps.
def ostree_update_vardeps(d):
    from ostree.ostreeupdate import VARIABLES
    return ' '.join(VARIABLES)

# Take a pristine rootfs as input, shuffle its layout around to make it
# OSTree-compatible, commit the rootfs into a per-build bare-user OSTree
# repository, and finally produce an OSTree-enabled rootfs by cloning
# and checking out the rootfs as an OSTree deployment.
fakeroot python do_ostree_prepare_rootfs () {
    from ostree.ostreeupdate import OSTreeUpdate
    OSTreeUpdate(d).prepare_rootfs()
}
do_ostree_prepare_rootfs[vardeps] += "${@ ostree_update_vardeps(d) }"

# .pub/.sec keys get created in the current directory, so
# we have to be careful to always run from the same directory,
# regardless of the image.
do_ostree_prepare_rootfs[dirs] = "${TOPDIR}"

def get_file_list(filenames):
    filelist = []
    for filename in filenames:
        filelist.append(filename + ":" + str(os.path.exists(filename)))
    return ' '.join(filelist)

do_ostree_prepare_rootfs[file-checksums] += "${@get_file_list(( \
   '${FLATPAKBASE}/scripts/gpg-keygen.sh', \
))}"

# TODO: ostree-native depends on ca-certificates,
# and is probably affected by https://bugzilla.yoctoproject.org/show_bug.cgi?id=9883.
# At least there are warnings in log.do_ostree_prepare_rootfs:
# (ostree:42907): GLib-Net-WARNING **: couldn't load TLS file database: Failed to open file '/fast/build/refkit/intel-corei7-64/tmp-glibc/work/x86_64-linux/glib-networking-native/2.50.0-r0/recipe-sysroot-native/etc/ssl/certs/ca-certificates.crt': No such file or directory
#
# In practice all our operations are local, so this probably
# doesn't matter.
do_ostree_prepare_rootfs[depends] += " \
    ostree-native:do_populate_sysroot \
"

# Take a per-build OSTree bare-user repository and export it to an
# archive-z2 repository which can then be exposed over HTTP for
# OSTree clients to pull in upgrades from.
fakeroot python do_ostree_publish_rootfs () {
    if d.getVar('OSTREE_REPO'):
       from ostree.ostreeupdate import OSTreeUpdate
       OSTreeUpdate(d).export_repo()
    else:
       bb.note("OSTree: OSTREE_REPO repository not set, not publishing.")
}
do_ostree_publish_rootfs[vardeps] += "${@ ostree_update_vardeps(d) }"

python () {
    # Don't do anything when OSTree image feature is off.
    if bb.utils.contains('IMAGE_FEATURES', 'ostree', True, False, d):
        # We must do this after do_image, because do_image
        # is still allowed to make changes to the files (for example,
        # prelink_image in IMAGE_PREPROCESS_COMMAND)
        #
        # We rely on wic to produce the actual images, so we inject our
        # custom rootfs creation task right before that.
        bb.build.addtask('do_ostree_prepare_rootfs', 'do_image_wic', 'do_image', d)

        # Publishing can run in parallel to wic image creation.
        bb.build.addtask('do_ostree_publish_rootfs', 'do_image_complete', 'do_ostree_prepare_rootfs', d)
}
