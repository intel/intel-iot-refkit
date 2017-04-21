#!/bin/sh

die() {
    echo "$@"
    exit 1
}

[ -n "$1" ] || die "$0: expecting keyname prefix in arguments"

PREFIX=$1

for i in pk kek db; do
    NAME=$PREFIX-$i
    BASENAME=`basename $NAME`
    openssl req -new -x509 -newkey rsa:2048 \
                -subj "/CN=$BASENAME/" \
                -keyout $NAME.key -out $NAME.crt \
                -days 365 -nodes -sha256
    openssl x509 -in $NAME.crt -out $NAME.cer -outform DER;
done
