# We expect to find our scripts here, in the scripts subdirectory.
FLATPAKBASE = "${FLATPAK_LAYERDIR}"

# Flatpak image base. We need to use this often in path names to avoid
# conflicts for repos of different ${MACHINES}. Although flatpak uses
# ostree as the backend for its repositories, the runtime branch naming
# conventions for flatpak ostree repositories is strict. Branches names
# must be of the form
#
#   runtime/ID/ARCH/VERSION
#
# Any other branches are silently ignored by flatpak. Therefore we cannot
# easily reuse (primary) repositories across multiple ${MACHINES} wihtout
# running into branch-naming conflicts. It is technically possible to share
# a primary bare-user repository if we teach the repository-exporting bits
# to do clever branch-name translations when pulling to the destination
# (exported, archive-z2) repository. However, since the exported repos anyway
# cannot be shared in this way there is not much point in doing so.
#
# As an additional restriction, ARCH must be from a known set, which is the
# one commonly used by the kernel, package managers, etc (although there is
# a slight chance that non-standard ARCHs work if explicitly overridden from
# the command-line... needs to be either tested or checked from the sources).
#
# Therefore, we translate ${MACHINE} to ${BUILD_ARCH} a.k.a ${FLATPAK_ARCH}
# in branch names while use ${MACHINE} as such in repository names.
#
FLATPAK_PN ?= "${@d.getVar('PN').split('-flatpak-')[0]}"

# Canonical ARCH flatpak will understand.
FLATPAK_ARCH ?= "${BUILD_ARCH}"

# Per-build per-${MACHINE} per-image primary bare-user flatpak repository.
FLATPAK_REPO = "${WORKDIR}/${FLATPAK_PN}.flatpak.${MACHINE}.bare-user"

# This is an archive-z2 repository where we export our builds for testing.
# This can be exposed over HTTP for consumption by flatpak. Among other
# things, this can be used to pull in the generated BaseSdk and BasePlatform
# repository branches to a development host for building flatpak applications
# against the corresponding flatpak-enabled image. Set this to empty if you
# don't want to automatically publish to such a repository.
FLATPAK_EXPORT ?= "${DEPLOY_DIR}/${FLATPAK_PN}.flatpak.${MACHINE}.archive-z2"

# We use the domain and the (canonical) branch together with ${MACHINE} to
# construct the full flatpak REFs of our base and SDK runtimes. The full REF
# is considered the canonical branch and is constructed as:
#
#  runtime/${FLATPAK_DOMAIN}.Base{Platform,Sdk}/${FLATPAK_ARCH}/${FLATPAK_BRANCH}
#
# Optionally we publish builds as two additional branches:
#
#   - an optional rolling 'latest' corresponding to the last build
#   - an optional rolling 'build' tagged with the ${BUILD_ID}
#
# Setting the corresponding variables for the optional branches to empty
# disables publishing/creating those branches.
#
FLATPAK_DOMAIN ?= "org.example"
FLATPAK_BRANCH ?= "${DISTRO_VERSION}"
FLATPAK_LATEST ?= "${DISTRO}/${FLATPAK_PN}/latest"
FLATPAK_BUILD  ?= "${DISTRO}/${FLATPAK_PN}/build/${BUILD_ID}"

# This is the GPG homedir and the key ID for signing repository commits. If
# you set the key ID to empty, signing is disabled altogether.
FLATPAK_GPGDIR ?= "${FLATPAKBASE}/../meta-refkit-core/files/gnupg"
FLATPAK_GPGID  ?= "${@d.getVar('DISTRO').replace(' ', '_') + \
                        '-development-signing@key'}"

# We can pre-populate the image during build with a set of pre-declared
# flatpak repositories and associated dedicated flatpak-session users.
# These repositories will be monitored for flatpaks and any new or updated
# flatpaks which are tagged for automatic installation will be pulled in
# and started within the appropriate flatpak session.
#
# To declare such a remote/repository, you need to
#   1) give the remote a unique name
#   2) provide a remote URL and a GPG public key for signature checking
#   3) associate a user with the remote
#
# The variable FLATPAK_APP_REPOS lists the names of the remotes to pre-
# declare and put into the image. For every remote <r> you have to provide
#
#   1) the remote HTTP URL in ${TOPDIR}/conf/<r>.url
#   2) the remote GPG signing public key in ${TOPDIR}/conf/<r>.key
#   3) provide passwd- and group entries for the associated user in
#        ${TOPDIR}/conf/flatpak-passwd and
#        ${TOPDIR}/conf/flatpak-group
#      The GECOS for the associated entry must be of the form
#      'flatpak user for <r>', where <r> is the remote name. By
#      convention the user's login ID is also <r>, but this is
#      not strictly necessary.
#
# By default we do not have any pre-declared application repositories,
# so FLATPAK_APP_REPOS defaults to empty.
FLATPAK_APP_REPOS ?= ""
