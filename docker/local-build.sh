#!/bin/bash

if [ -z "$WORKSPACE" ]; then
	echo "Define WORKSPACE location"
	exit 1
fi

CURRENT_PROJECT=refkit
BUILD_DIR=${BUILD_DIR:-${WORKSPACE}/build}
BUILD_CACHE_DIR=$BUILD_DIR/bb-cache
BUILDOS="crops-yocto-ubuntu-17"
GIT_PROXY_COMMAND=oe-git-proxy
TARGET_MACHINE="intel-corei7-64"

BUILD_ARGS="--build-arg uid=`id -u`"
RUN_ARGS=(-u "`id -u`")

safe_proxy_vars="HTTP_PROXY http_proxy HTTPS_PROXY https_proxy FTP_PROXY ftp_proxy NO_PROXY no_proxy ALL_PROXY socks_proxy SOCKS_PROXY"

for proxy in $safe_proxy_vars; do
    # Use variable only if value defined.
    # Note that this is different thing from variable defined empty
    # Avoid use bash-specific [ -v var ] for portability
    if [ "$(env|grep $proxy)" != "" ]; then
        eval _proxyval=\$$proxy
        # strip spaces from values, if any.
        val="`echo ${_proxyval} | tr -d ' '`"
        BUILD_ARGS="$BUILD_ARGS --build-arg $proxy=${val}"
        RUN_ARGS+=(-e "$proxy=${_proxyval}")
    fi
done

BUILD_TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`

if [ -f "$WORKSPACE/.build_number" ]; then
	BUILD_NUMBER=`cat $WORKSPACE/.build_number`
	let "BUILD_NUMBER=BUILD_NUMBER+1"
else
	BUILD_NUMBER=1
fi
echo "$BUILD_NUMBER" > $WORKSPACE/.build_number

CI_BUILD_ID="${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}"

# export other vars
for var in WORKSPACE BUILD_DIR BUILD_CACHE_DIR GIT_PROXY_COMMAND CI_BUILD_ID TARGET_MACHINE BB_ENV_EXTRAWHITE $BB_ENV_EXTRAWHITE; do
	RUN_ARGS+=(-e "$var=${!var}")
done
# Point HOME to WORKSPACE, don't polute real home.
RUN_ARGS+=(-e "HOME=$WORKSPACE")

docker build -t $CURRENT_PROJECT $BUILD_ARGS $WORKSPACE/docker/$BUILDOS

if [ ! -d $BUILD_CACHE_DIR ]; then
    mkdir -p $BUILD_CACHE_DIR
fi

docker run -it --rm "${RUN_ARGS[@]}" \
	-v $BUILD_DIR:$BUILD_DIR:rw \
	-v $BUILD_CACHE_DIR:$BUILD_CACHE_DIR:rw \
	-v $WORKSPACE:$WORKSPACE:rw \
	-w $WORKSPACE \
	$CURRENT_PROJECT $WORKSPACE/docker/build-project.sh "$@"

