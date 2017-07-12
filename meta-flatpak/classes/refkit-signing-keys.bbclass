#
# This class can be used to generate (or import) a set of signing keys,
# for whatever purpose the build might need those. Once such purpose is
# the signing of base OS and flatpak ostree repositories.
#
# To make sure all the necessary keys get generated list them in your
# local.conf (or some other global configuration file) by setting
# REFKIT_SIGNING_KEYS to necessary key IDs.

# This is the directory we look for pre-generated keys in. If we find a
# pre-generated key pair for any key id (we assume the key files be named
# as <key-id>.pub and <key-id>.sec) we import those instead of generating
# them anew.
REFKIT_SIGNING_KEYDIR ?= "${FLATPAK_LAYERDIR}/../meta-refkit-core/files/gpg-keys"

# Signing keys to generate, a list of key IDs.
REFKIT_SIGNING_KEYS    ?= ""

# This is where we put our GPG homedir, export keys to, etc.
REFKIT_SIGNING_GPGDIR  ?= "${DEPLOY_DIR}/gnupg"

# How long we let two parallel key generation tasks clash.
REFKIT_SIGNING_TIMEOUT ?= "60"

# task to generate/check all requested signing keys
fakeroot do_generate_signing_keys () {
    # Bail out early if we have no keys to generate.
    if [ -z "${REFKIT_SIGNING_KEYS}" -o -z "${REFKIT_SIGNING_GPGDIR}" ]; then
        echo "No GPG key IDs or directory set, nothing to do..."
        return 0
    fi

    # When building several images in parallel (e.g. in CI), we have to
    # make sure we don't let two tasks start generating the same signing
    # key into the keyring. While GPG itself seems to semi-gracefully
    # survive a keyring with duplicate key ids, gpgme (or maybe just ostree,
    # I did not bother checking it) segfaults in such a case.
    # Therefore, we have this unholy kludge where we use mkdir(2) as a
    # lock, and let the task getting there first do the deed, while the
    # second one just waits for the first to finish (and consequently causes
    # its own dependent tasks to properly wait for the keys to get generated).
    # Yuck...

    dir="${REFKIT_SIGNING_GPGDIR}"
    mkdir -p "${dir%/*}"
    mkdir "${dir}.lock" || { # Forgive me Thompson&Dijkstra, for I have sinned...
        slept=0
        for id in ${REFKIT_SIGNING_KEYS}; do
            while [ $slept -lt ${REFKIT_SIGNING_TIMEOUT} ]; do
                if [ ! -e ${dir}/$id.sec ]; then
                    echo "Waiting for generation of signing key $id..."
                    sleep 3
                    slept=$( expr $slept + 3 )
                else
                    echo "Got signing key $id..."
                    break
                fi
            done
        done
        if [ $slept -ge ${REFKIT_SIGNING_TIMEOUT} ]; then
            echo "Signing key generation timed out..."
            return 1
        else
            return 0
        fi
    }

    dir="${REFKIT_SIGNING_GPGDIR}"
    for id in ${REFKIT_SIGNING_KEYS}; do
        pubkey="$dir/$id.pub"
        seckey="$dir/$id.sec"
        pubpre="${REFKIT_SIGNING_KEYDIR}/$id.pub"
        secpre="${REFKIT_SIGNING_KEYDIR}/$id.sec"

        if [ -e $pubpre -a -e $secpre ]; then
             echo "Re-using pre-generated key-pair $pubpre/$secpre..."
            # gpg-keygen.sh below will import these keys. It actually
            # races with any conflicting task waiting for the keys above,
            # but that should be okay...ish... fast importing winning.
            mkdir -p $dir
            cp $pubpre $pubkey
            cp $secpre $seckey
        fi

        # Generate repository signing GPG keys, if we don't have them yet.
        echo "Generating/checking signing key $id..."

        ${FLATPAKBASE}/scripts/gpg-keygen.sh \
            --home $dir \
            --id $id \
            --pub $pubkey \
            --sec $seckey
    done

    rmdir "${dir}.lock"
}

do_generate_signing_keys[depends] += " \
    gnupg1-native:do_populate_sysroot \
"

addtask generate_signing_keys before do_rootfs
