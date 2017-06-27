DESCRIPTION = "Repository/remo URLs and signing keys for pre-declared flatpak session/application repositories."
HOMEPAGE = "http://127.0.0.1/"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
    git://git@github.com/klihub/flatpak-predefined-repos.git;protocol=https;branch=master \
"

SRCREV = "1181642d571d575783760247792c45635e6d3ebf"

S = "${WORKDIR}/git"

inherit autotools flatpak-config

# For each repo named <r> we expect a <r>.url and <r>.key file (containing
# the repo URL and the repo pubic GPG key), and passwd/group entries for
# the associated users.
#
# Turn the space-separated repo name list into a comma-separated one and
# pass it to configure.
EXTRA_OECONF += " \
    --with-repos=${@','.join(d.getVar('FLATPAK_APP_REPOS').split())} \
"

# Inherit useradd only if we have pre-declared repositories. Otherwise
# useradd would bail out with a parse-time error when we don't set
# USERADD_PARAM_${PN} when we don't have pre-declared repos to put into
# the image.
inherit ${@'useradd' if d.getVar('FLATPAK_APP_REPOS') else ''}

# Ask for the creation of the users/groups associated with the pre-declared
# remotes/repositories. Turn the space-separated list into a semi-colon-
# separated one.
USERADD_PACKAGES = "${PN}"
USERADD_PARAM_${PN} = "${@';'.join(d.getVar('FLATPAK_APP_REPOS').split())}"

FILES_${PN} = " \
    ${sysconfdir}/flatpak-session/* \
"

do_configure_prepend () {
    if [ -n "${FLATPAK_APP_REPOS}" ]; then
        mkdir -p ${S}/repos

        for _r in ${FLATPAK_APP_REPOS}; do
            echo "Copying URL- and key-file for remote/repository $_r..."
            cp ${TOPDIR}/conf/$_r.url ${S}/repos
            cp ${TOPDIR}/conf/$_r.key ${S}/repos
        done
    else
        echo "No predefined flatpak application remotes/repos."
    fi
}
