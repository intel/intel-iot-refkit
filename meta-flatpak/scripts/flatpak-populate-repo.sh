#!/bin/bash


# Print an informational message an exit (currently unconditionally).
msg () {
    echo "$*"
}

# Print a fatal error message and exit.
fatal () {
    echo "fatal error: $*"
    exit 1
}

# Print help on usage.
print_usage () {
    if [ -n "$*" ]; then
        echo "$*"
    fi

    echo "usage: $0 [options]"
    echo ""
    echo "Take a runtime or SDK image sysroot directory and commit it into a"
    echo "flatpak/OSTree repository. If the repository does not exist by"
    echo "default it is created in archive-z2 mode. Such a repository is"
    echo "suitable to be exported over HTTP/HTTPS for flatpak clients to fetch"
    echo "fetch runtime/SDK images and flatpak application from."
    echo "archive-z2 format, suitable to be exported over HTTP for clients to"
    echo "fetch data from."
    echo ""
    echo "The other possible options are:"
    echo "  --repo-path <repo>    path to flatpak repository to populate"
    echo "  --repo-mode <type>    repository mode [bare-user]"
    echo "  --repo-export <exp>   export the image also to archive-z2 <exp>"
    echo "  --gpg-home <dir>      GPG home directory for keyring"
    echo "  --gpg-id <id>         GPG key id to use for signing"
    echo "  --branches <list>     branches to commit/export to repository"
    echo "  --machine <machine>   full MACHINE"
    echo "  --image-sysroot <dir> image sysroot directory"
    echo "  --tmpdir <dir>        temporary directory to use"
    echo "  --subject <msg>       commit subject message"
    echo "  --body <msg>          commit body message"
    echo "  --image-libs <file>   provided image library file"
    echo "  --help                print this help and exit"

    if [ -n "$*" ]; then
        exit 1
    else
        exit 0
    fi
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --repo-path|--repo|-r)
                REPO_PATH=$2
                shift 2
                ;;
            --repo-mode)
                REPO_MODE=$2
                shift 2
                ;;

            --repo-export|--export|-e)
                REPO_EXPORT=$2
                shift 2
                ;;

            --gpg-home|--gpg-homedir)
                GPG_HOME=$2
                shift 2
                ;;

            --gpg-id)
                GPG_ID=$2
                shift 2
                ;;

            --branches)
                REPO_BRANCHES="$2"
                shift 2
                ;;

            --machine)
                MACHINE="$2"
                shift 2
                ;;

            --image-sysroot|--image)
                IMAGE_SYSROOT=$2
                shift 2
                ;;

            --tmp-dir|--tmp)
                TMPDIR=$2
                shift 2
                ;;

            --subject)
                COMMIT_SUBJECT="$2"
                shift 2
                ;;

            --body)
                COMMIT_BODY="$2"
                shift 2
                ;;

            --image-libs|--libs)
                LIBRARIES=$2
                shift 2
                ;;

            --help|-h)
                print_usage
                exit 0
                ;;

            *)
                print_usage "Unknown command line option/argument $1."
                ;;
        esac
    done

    if [ -z "$REPO_PATH" ]; then
        print_usage "missing repository path (--repo-path)"
    fi

    if [ ! -e "$REPO_PATH" -a -z "$IMAGE_SYSROOT" ]; then
        print_usage "missing image sysroot (--image-sysroot)"
    fi

    if [ ! -d $REPO_PATH -a -z "$REPO_BRANCHES" ]; then
        print_usage "missing branches (--branches)"
    fi

    if [ -z "$TMPDIR" ]; then
        TMPDIR="$IMAGE_SYSROOT.flatpak-tmp.$$"
    else
        TMPDIR="$TMPDIR/flatpak-tmp.$$"
    fi

    FLATPAK_SYSROOT=$TMPDIR/flatpak-sysroot
    METADATA=$FLATPAK_SYSROOT/metadata
}

# Create image metadata file for the repository.
metadata_generate () {
    local _platform _sdk _name
    local _sdk

    msg "* Generating metadata file ($METADATA)..."

    _platform="${REPO_BRANCHES%%,*}"
    _platform="${_platform#runtime/}"
    _sdk="${_platform/BasePlatform/BaseSdk}"
    _name="${_platform%%/*}"

    (echo "[Runtime]"
     echo "name=$_name"
     echo "runtime=$_platform"
     echo "sdk=$_sdk") > $METADATA
}

# Populate temporary sysroot with flatpak-translated path names.
sysroot_populate () {
    msg "* Creating flatpak sysroot ($FLATPAK_SYSROOT) from $IMAGE_SYSROOT..."

    mkdir -p $FLATPAK_SYSROOT
    bsdtar -C $IMAGE_SYSROOT -cf - ./usr ./etc | \
        bsdtar -C $FLATPAK_SYSROOT \
            -s ":^./usr:./files:S" \
            -s ":^./etc:./files/etc:S" \
            -xvf -
}

# Clean up temporary sysroot.
sysroot_cleanup () {
    msg "* Cleaning up $TMPDIR, $FLATPAK_SYSROOT..."
    rm -rf $TMPDIR
}

# Initialize flatpak/OSTree repository, if necessary.
repo_create () {
    local _path="$1"
    local _mode="${2:-bare-user}"

    if [ -d $_path ]; then
        if [ -f $_path/config -a grep -q $_mode $_path/config ]; then
            msg "* Using existing $_mode repository $_path..."
            return 0
        fi

        fatal "Existing repository $_path is not a $_mode repo."
    fi

    msg "* Creating $_mode repository $_path..."

    mkdir -p $_path
    ostree --repo=$_path init --mode=$_mode
}

# Populate the repository.
repo_populate () {
    local _b _ref _content

    # OSTree can't handle files with no read permission
    msg "* Fixup permissions for OSTree..."
    find $FLATPAK_SYSROOT -type f -exec chmod u+r {} \;

    IMAGE_VERSION=$(cat $IMAGE_SYSROOT/etc/version)
    if [ -z "$COMMIT_SUBJECT" ]; then
        COMMIT_SUBJECT="Commit of image $IMAGE_VERSION."
    fi

    #IMAGE_BUILD="$(cat $IMAGE_SYSROOT/etc/build)"
    if [ -z "$COMMIT_BODY" ]; then
        COMMIT_BODY="Commit of image $IMAGE_VERSION."
    fi
    
    _ref=""
    for _b in ${REPO_BRANCHES//,/ }; do
        if [ -z "$_ref" ]; then
            msg "* Committing base/canonical branch $_b..."
            _content="$FLATPAK_SYSROOT"
            _ref=$_b
        else
            msg "* Committing additional branch $_b..."
            _content="--tree=ref=$_ref"
        fi

        ostree --repo=$REPO_PATH commit \
           $GPG_SIGN \
           --owner-uid=0 --owner-gid=0 --no-xattrs \
           --subject "$COMMIT_SUBJECT" \
           --body "$COMMIT_BODY" \
           --branch=$_b $_content

        msg "* Updating repository summary..."
        ostree --repo=$REPO_PATH summary -u $GPG_SIGN
    done
}

# Mirror the branch we created to our export repository.
repo_export () {
    local _from="$1"
    local _to="${2:-$_from.archive-z2}"
    local _ref

    for _ref in $(ostree --repo=$_from refs); do
        msg "* Exporting branch $_ref to $_to..."
        ostree --repo=$_to pull-local $_from $_ref
        ostree --repo=$_to summary -u $GPG_SIGN
    done

    repo_apache_config $_to
}

# Generate and HTTP configuration fragment for the exported repository.
repo_apache_config () {
    local _path=$1
    local _alias

    cd $_path && _path=$(pwd) && cd - >& /dev/null
    if [ -n "${MACHINE}" ]; then
        _alias="/flatpak/${MACHINE}/"
    else
        _alias="/flatpak/"
    fi

    msg "* Generating apache2 config fragment for $_path..."
    (echo "Alias \"$_alias\" \"$_path/\""
     echo ""
     echo "<Directory $_path>"
     echo "    Options Indexes FollowSymLinks"
     echo "    Require all granted"
     echo "</Directory>") > $_path.http.conf
}

# Generate list of libraries provided by the image.
generate_lib_list () {
    [ -z "$LIBRARIES" ] && return 0

    msg "* Generating list of provided libraries..."
    (cd $IMAGE_SYSROOT; find . -type f -name lib\*.so.\*) | \
        sed 's#^\./#/#g' > $LIBRARIES
}

# Fixup gpg2 relocation related overall crapness.
gpg2_kludgeup () {
    local _expected _real

    if [ -z "$GPG_HOME" ]; then
        return 0
    fi

    _expected=$(gpgconf | grep ^gpg: | cut -d ':' -f 3)
    _real=$(which gpg2)

    if [ -n "$_expected" -a -n "$_real" -a "$_expected" != "$_real" ]; then
        msg "Temporarily symlinking gpg2 binary to expected location..."
        ln -s $_real $_expected
    fi
}

# Undo gpg2 relocation kludge
gpg2_cleanup () {
    local _expected _real

    if [ -z "$GPG_HOME" ]; then
        return 0
    fi

    _expected=$(gpgconf | grep ^gpg: | cut -d ':' -f 3)
    _real=$(which gpg2)

    if [ -n "$_expected" -a -n "$_real" -a "$_expected" != "$_real" ]; then
        msg "* Removing gpg2 kludge symlink..."
        rm -f $_expected
    fi
}

#########################
# main script

REPO_PATH=""
REPO_MODE=""
REPO_EXPORT=""
IMAGE_SYSROOT=""
TMPDIR=""
REPO_BRANCHES=""
GPG_HOME=""
GPG_ID=""

parse_command_line $*

msg "Flatpak repository population/exporting:"
msg "      image repo: $REPO_PATH"
msg "   image sysroot: ${IMAGE_SYSROOT:-none}"
msg "   temporary dir: $TMPDIR"
msg "    library list: $LIBRARIES"
msg "     export repo: $REPO_EXPORT"
msg "        branches: ${REPO_BRANCHES//,/ }"
msg "  commit subject: $COMMIT_SUBJECT"
msg "     commit body: $COMMIT_BODY"
msg "        GPG home: ${GPG_HOME:-none}"
msg "  GPG signing id: ${GPG_ID:-none}"

set -e

if [ -n "$GPG_ID" ]; then
    GPG_SIGN="--gpg-homedir=${GPG_HOME:-~/.gnupg} --gpg-sign=$GPG_ID"
else
    GPG_SIGN=""
fi

# gpg2_kludgeup

if [ ! -e $REPO_PATH ]; then
    repo_create $REPO_PATH $REPO_MODE
    sysroot_populate
    metadata_generate
    repo_populate
    sysroot_cleanup
fi

if [ -n "$REPO_EXPORT" ]; then
    if [ ! -d $REPO_EXPORT ]; then
        repo_create $REPO_EXPORT archive-z2
    fi

    repo_export $REPO_PATH $REPO_EXPORT
fi

# gpg2_cleanup
