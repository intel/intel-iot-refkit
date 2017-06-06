#!/bin/bash

# Print an informational message (currently unfiltered).
msg () {
    echo "$*"
}

# Print a fatal error message and exit.
fatal () {
    echo "fatal error: $*" 2>1
    exit 1
}

# Print help on usage.
print_usage () {
    if [ -n "$*" ]; then
        echo "$*"
    fi

    echo "usage: $0 -c config | -o output [ options ]"
    echo ""
    echo "Generate GPG signing keyring for our flatpak/OSTree repository and"
    echo "export the generated public and secret keys from the keyring."
    echo ""
    echo "The possible options are:"
    echo "  --home <home>          GPG home directory for the keyring"
    echo "  --id <key-id>          key ID to check/generate"
    echo "  --pub <file>           public key file to produce/import"
    echo "  --sec <file>           secret key file to produce/import"
    echo "  --config <file>        use provided config, ignore other options"
    echo "  --type <type>          key type to generate"
    echo "  --length <bits>        key length to use"
    echo "  --subkey-type <type>   subkey type to generate"
    echo "  --subkey-length <bits> subkey length to use"
    echo "  --name <name>          real name associated with the generated key"
    echo "  --gpg2                 import keys to GPG2 keyring as well"
    echo "  --help                 show this help"

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
            --home|-H)
                GPG_HOME="$2"
                shift 2
                ;;
            --id)
                GPG_ID="$2"
                shift 2
                ;;
            --pub)
                GPG_PUB="$2"
                shift 2
                ;;
            --sec)
                GPG_SEC="$2"
                shift 2
                ;;
            --type|-T)
                GPG_TYPE="$2"
                shift 2
                ;;
            --length|-L)
                GPG_LENGTH="$2"
                shift 2
                ;;
            --subkey-type|-t)
                GPG_SUBTYPE="$2"
                shift 2
                ;;
            --subkey-length|-l)
                GPG_SUBLENGTH="$2"
                shift 2
                ;;
            --name|-n)
                GPG_NAME="$2"
                shift 2;
                ;;
            --config|-c)
                GPG_CONFIG="$2"
                shift 2
                ;;
            --gpg2|-2)
                GPG2_IMPORT="yes"
                ;;
            --help|-h)
                print_usage
                ;;
            *)
                print_usage "Invalid options/argument $1"
                ;;
        esac
    done

    if [ -z "$GPG_HOME" ]; then
        GPG_HOME="~/.gnupg"
    fi

    if [ -z "$GPG_ID" ]; then
        fatal "missing key ID (--id)"
    fi

    if [ -z "$GPG_PUB" ]; then
        GPG_PUB="$GPG_HOME/$GPG_ID.pub"
    fi

    if [ -z "$GPG_SEC" ]; then
        GPG_SEC="$GPG_HOME/$GPG_ID.sec"
    fi

    if [ -z "$GPG_NAME" ]; then
        GPG_NAME="Signing Key"
    fi

    msg "GPG key generation configuration:"
    msg "        home: $GPG_HOME"
    msg "      key ID: $GPG_ID"
    msg "  public key: $GPG_PUB"
    msg "  public key: $GPG_SEC"
    msg "      name: $GPG_NAME"
}

# Check and create GPG home directory if necessary.
gpg1_chkhome ()
{
    if [ ! -d $GPG_HOME ]; then
        mkdir -p $GPG_HOME
        chmod og-rwx $GPG_HOME
    else
        chmod og-rwx $GPG_HOME
    fi
}

# Check if the requested keys are already in the keyring.
gpg1_chkkeyrings ()
{
    if $GPG1 --list-keys | grep -q -e "<$GPG_ID>" && \
       $GPG1 --list-secret-keys | grep -q -e "<$GPG_ID>"; then
        return 0
    else
        return 1
    fi
}

# Check if the requested keys already exist.
gpg1_chkkeys ()
{
    if [ ! -e $GPG_PUB -o ! -e $GPG_SEC ]; then
        msg "* Key files $GPG_PUB/$GPG_SEC not found..."
        rm -f $GPG_PUB $GPG_SEC
        if gpg1_chkkeyrings; then
            msg "* Keys ($GPG_ID) already in keyrings, exporting..."
            $GPG1 --export --output $GPG_PUB $GPG_ID
            $GPG1 --export-secret-keys --output $GPG_SEC $GPG_ID
        else
            return 1
        fi
    else
        if ! gpg1_chkkeyrings; then
            msg "* Importing keys $GPG_SEC, $GPG_PUB..."
            $GPG1 --import $GPG_PUB
            $GPG1 --import $GPG_SEC
        fi
    fi
}

# Generate GPG --batch mode key generation configuration file (unless given).
gpg1_mkconfig () {
    if [ -n "$GPG_CONFIG" ]; then
        if [ ! -f "$GPG_CONFIG" ]; then
            fatal "Missing GPG key configuration $GPG_CONFIG."
        fi
        msg "* Using provided GPG key configuration: $GPG_CONFIG"
    else
        GPG_CONFIG="$GPG_HOME/$GPG_ID.cfg"

        msg "* Generating GPG key configuration $GPG_CONFIG..."

        (echo "%echo Generating GPG signing keys ($GPG_PUB, $GPG_SEC)..."
	 echo "Key-Type: $GPG_TYPE"
	 echo "Key-Length: $GPG_LENGTH"
	 echo "Subkey-Type: $GPG_SUBTYPE"
	 echo "Subkey-Length: $GPG_SUBLENGTH"
	 echo "Name-Real: $GPG_NAME"
	 echo "Name-Email: $GPG_ID"
	 echo "Expire-Date: 0"
	 echo "%pubring $GPG_PUB"
	 echo "%secring $GPG_SEC"
	 echo "%commit"
	 echo "%echo done") > $GPG_CONFIG
    fi
}

# Generate GPG1 keys and keyring.
gpg1_genkeys () {
    msg "* Generating GPG1 keys and keyring..."

    $GPG1 --batch --gen-key $GPG_CONFIG
    $GPG1 --import $GPG_SEC
    $GPG1 --import $GPG_PUB
}

# Mark all keys trusted in our keyring.
gpg1_trustkeys () {
    local _trustdb=$GPG_HOME/gpg.trustdb _fp

    #
    # This is a bit iffy... we misuse a supposedly private
    # GPG API (the trust DB format).
    #

    msg "* Marking keys trusted in keyring..."

    $GPG1 --export-ownertrust > $_trustdb

    # Note: we might end up with duplicates but that's ok...
    for _fp in $($GPG1 --fingerprint | \
                     grep " fingerprint = " | sed 's/^.* = //g;s/ //g'); do
        echo $_fp:6: >> $_trustdb
    done

    $GPG1 --import-ownertrust < $_trustdb
    rm -f $_trustdb
}

# Import keys to GPG2 keyring.
gpg2_import () {
    if [ "$GPG2_IMPORT" = "yes" ]; then
        msg "* Importing keys to GPG2 keyring..."
        $GPG1 --export-secret-keys | $GPG2 --import
    else
        msg "* GPG2 import not requested, skipping..."
    fi
}


#########################
# main script

GPG_HOME=""
GPG_ID=""
GPG_PUB=""
GPG_SEC=""
GPG_TYPE="DSA"
GPG_LENGTH="2048"
GPG_SUBTYPE="ELG-E"
GPG_SUBLENGTH="2048"
GPG_NAME=""
GPG_CONFIG=""
GPG2_IMPORT=""

parse_command_line $*

set -e

GPG1="gpg --homedir=$GPG_HOME"
GPG2="gpg2 --homedir=$GPG_HOME"

gpg1_chkhome

if ! gpg1_chkkeys; then
    gpg1_mkconfig
    gpg1_genkeys
    gpg1_trustkeys
fi

gpg2_import
