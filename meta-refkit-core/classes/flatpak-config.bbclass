# We expect to find our scripts here, in the scripts subdirectory.
FLATPAKBASE = "${META_REFKIT_CORE_BASE}"

# This is a per-build per-image primary bare-user flatpak repository.
FLATPAK_REPO = "${WORKDIR}/flatpak.bare-user"

# This is an archive-z2 repository where we export our builds for testing.
# This can be exposed over HTTP for consumption by flatpak. Among other
# things, this can be used to pull in the generated BaseSdk and BasePlatform
# repository branches to a development host for building flatpak applications
# against the corresponding flatpak-enabled image. Set this to empty if you
# don't want to automatically publish to such a repository.
FLATPAK_EXPORT ?= "${TMPDIR}/flatpak.archive-z2"

# We use the domain and the (canonical) branch together with ${MACHINE} to
# construct the full flatpak REFs of our base and SDK runtimes. The full REF
# is considered the canonical branch and is constructed as:
#
#     runtime/${FLATPAK_DOMAIN}.Base{Platform,Sdk}/${MACHINE}/${FLATPAK_BRANCH}
#
# Optionally we publish builds as two additional branches:
#
#   - an optional rolling 'latest' corresponding to the last build
#   - an optional rolling 'build' tagged with the ${BUILD_ID}
#
# Setting the corresponding variables for the optional branches to empty
# disables publishing/creating those branches.
FLATPAK_DOMAIN ?= "example.org"
FLATPAK_BASE   ?= "${@d.getVar('PN').split('-flatpak-')[0]}"
FLATPAK_BRANCH ?= "${DISTRO}/${FLATPAK_BASE}/${DISTRO_VERSION}"
FLATPAK_LATEST ?= "${DISTRO}/${FLATPAK_BASE}/latest"
FLATPAK_BUILD  ?= "${DISTRO}/${FLATPAK_BASE}/build/${BUILD_ID}"

# This is the GPG key id of our repository signing key. If you set this to
# empty, signing is disabled altogether.
FLATPAK_GPGID ?= "refkit-signing@key"
