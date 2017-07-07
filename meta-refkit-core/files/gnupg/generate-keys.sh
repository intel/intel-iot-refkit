#!/bin/bash

print_usage () {
    if [ -n "$1" ]; then
        echo "$1"
    fi

    echo "$0 generates a DSA GPG key-pair without password protection,"
    echo "suitable for signing commits in an flatpak/ostree repository."
    echo ""
    echo "usage: $0 gpg-homedir key-id"
    echo ""
    echo "For example, running"
    echo ""
    echo "    $0 \$(pwd)/gpg-home release@example.org"
    echo ""
    echo "generates a GPG key-pair and imports the keys into the GPG keyrings"
    echo "in \$(pwd)/gpg-home. It also leaves the exported key pair, and the"
    echo "gpg1 batch mode configuration file used to generate the keys as"
    echo ""
    echo "    release@example.org.pub,"
    echo "    release@example.org.sec, and"
    echo "    release@example.org.cfg"
    echo ""
    echo "in \$(pwd)/gpg-home."
    echo ""
    echo "You need gpg1 installed to use this script."

    exit ${2:-1}
}

if [ "$1" = "-h" -o "$1" = "--help" ]; then
    print_usage "" 0
fi

if [ "$#" != "2" ]; then
    print_usage "invalid command line \"$*\"" 1
fi

${0%/*}/../../../meta-flatpak/scripts/gpg-keygen.sh \
    --home "$1" --id "$2" --pub "$1/$2.pub" --sec "$1/$2.sec"
