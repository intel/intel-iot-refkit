# build-common-util.sh: common functions for build scripts
# Copyright (c) 2017, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

auto_conf_common() {
    # Initialize auto.conf from local CI preferences if present
    if [ -f $WORKSPACE/meta-*/conf/distro/include/refkit-ci.inc ]; then
      cat $WORKSPACE/meta-*/conf/distro/include/refkit-ci.inc > conf/auto.conf
    fi

    cat >> conf/auto.conf << EOF
MACHINE = "$TARGET_MACHINE"
EOF

    if [ -n "$BUILD_CACHE_DIR" ]; then
        cat >> conf/auto.conf << EOF
DL_DIR = "${BUILD_CACHE_DIR}/sources"
EOF
    fi

    if [ ! -z ${JOB_NAME+x} ]; then
        # in CI run only:
        if [ ! -z ${COORD_BASE_URL+x} ]; then
            # SSTATE over http
            echo "SSTATE_MIRRORS ?= \"file://.* ${COORD_BASE_URL}/bb-cache/sstate/PATH\"" >> conf/auto.conf
        fi
    else
      # save sstate to workspace
      echo "SSTATE_DIR = \"${BUILD_CACHE_DIR}/sstate\"" >> conf/auto.conf
    fi
    # lower compression levels in a PR build, to save build time
    if [ -z ${CI_ARCHIVER_MODE+x} ]; then
        echo "ZIP_COMPRESSION_LEVEL ?= \"-1\"" >> conf/auto.conf
        echo "XZ_COMPRESSION_LEVEL ?= \"-0\"" >> conf/auto.conf
    fi
}

auto_conf_archiver() {
    # Archiver set optionally: Product build has it, PR job does not.
    if [ ! -z ${CI_ARCHIVER_MODE+x} ]; then
        cat >> conf/auto.conf << EOF
INHERIT += "archiver"
ARCHIVER_MODE[src] = "original"
ARCHIVER_MODE[diff] = "1"
ARCHIVER_MODE[recipe] = "1"
EOF
    fi
}

auto_conf_buildhistory() {
    # Buildhistory mode set always in CI run
    cat >> conf/auto.conf << EOF
INHERIT += "buildhistory"
BUILDHISTORY_COMMIT = "1"
INHERIT += "buildhistory-extra"
BUILDHISTORY_DIR ?= "${BUILDHISTORY_TMP}"
EOF
}
