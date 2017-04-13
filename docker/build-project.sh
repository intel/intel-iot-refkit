#!/bin/bash -xeu
# build-project.sh: Build images for specific layer project
# Copyright (c) 2016, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# Catch errors in pipelines
set -o pipefail

BUILD_TARGET="$@"

# bitbake started to depend on a locale with UTF-8 support
# when migrating to Python3.
export LC_ALL=en_US.UTF-8

cd $WORKSPACE

# use +u to avoid exit caused by unbound variables use in init scripts
set +u
# BUILD_DIR is undef in CI case, but is set in local-build case.
source refkit-init-build-env ${BUILD_DIR}
set -u

if [ ! -z ${JOB_NAME+x} ]; then
  # in CI run only:
  # get commit ID for using in buildhistory tagging, save for later use
  CI_GIT_COMMIT=$(git rev-parse HEAD)
  echo ${CI_GIT_COMMIT} > ${WORKSPACE}/ci_git_commit

  # Prepare for buildhistory generation in BH branch, name of which
  # is composed from JOB_NAME and TARGET_MACHINE
  _BUILDHISTORY_DIR="${PUBLISH_DIR}/buildhistory"
  BUILDHISTORY_TMP=${WORKSPACE}/buildhistory
  BUILDHISTORY_BRANCH="${JOB_NAME}/${TARGET_MACHINE}"

  # Clone master buildhistory, checkout this build speficic branch
  rm -fr ${BUILDHISTORY_TMP}
  git clone ${_BUILDHISTORY_DIR} ${BUILDHISTORY_TMP}
  pushd ${BUILDHISTORY_TMP}
  if ! git checkout ${BUILDHISTORY_BRANCH} --; then
    git checkout --orphan ${BUILDHISTORY_BRANCH} --;
    git reset
    git clean -fdx
  fi
  git rm --ignore-unmatch -rf . >/dev/null
  popd
fi

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
  # Archiver set optionally: Product build has it, PR job does not.
  if [ ! -z ${CI_ARCHIVER_MODE+x} ]; then
    cat >> conf/auto.conf << EOF
INHERIT += "archiver"
ARCHIVER_MODE[src] = "original"
ARCHIVER_MODE[diff] = "1"
ARCHIVER_MODE[recipe] = "1"
EOF
  fi
  # Buildhistory mode set always in CI run
  cat >> conf/auto.conf << EOF
INHERIT += "buildhistory"
BUILDHISTORY_COMMIT = "1"
INHERIT += "buildhistory-extra"
BUILDHISTORY_DIR ?= "${BUILDHISTORY_TMP}"
EOF
  if [ ! -z ${COORD_BASE_URL+x} ]; then
    # SSTATE over http
    echo "SSTATE_MIRRORS ?= \"file://.* ${COORD_BASE_URL}/bb-cache/sstate/PATH\"" >> conf/auto.conf
  else
    # SSTATE mirror over NFS
    echo "SSTATE_MIRRORS ?= \"file://.* file://${BUILD_CACHE_DIR}/sstate/PATH\"" >> conf/auto.conf
  fi
else
  # save sstate to workspace
  echo "SSTATE_DIR = \"${BUILD_CACHE_DIR}/sstate\"" >> conf/auto.conf
fi
export BUILD_ID=${CI_BUILD_ID}
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE BUILD_ID"

if [ -z "$BUILD_TARGET" ]; then
  # Try to read build targets from configured CI specific settings.
  # refkit_ci_vars is made in pre-build script in CI run, but
  # may need to be created in local-build run.
  if [ ! -f ${WORKSPACE}/refkit_ci_vars ]; then
    # use bitbake -e for variables parsing, then pick REFKIT_CI part
    bitbake -e >bb_e_out 2>bb_e_err || (cat bb_e_err && false)
    grep -E "^REFKIT_CI" bb_e_out > ${WORKSPACE}/refkit_ci_vars || true
  fi
  _bitbake_targets=""
  for ci_var in `perl -pe "s/^([A-Z_]+)=.+/\1/g" ${WORKSPACE}/refkit_ci_vars`; do
    case "$ci_var" in
    (REFKIT_CI_BUILD_TARGETS) _sufx="" ;;
    (REFKIT_CI_SDK_TARGETS) _sufx=":do_populate_sdk" ;;
    (REFKIT_CI_ESDK_TARGETS) _sufx=":do_populate_sdk_ext" ;;
    (REFKIT_CI_TEST_EXPORT_TARGETS) _sufx=":do_test_iot_export" ;;
    (REFKIT_CI_FLATPAK_RUNTIME_TARGETS) _sufx="-flatpak-runtime:do_test_iot_export" ;;
    (REFKIT_CI_FLATPAK_SDK_TARGETS) _sufx="-flatpak-sdk" ;;
    (*) continue;;
    esac
    for img in `grep ${ci_var} ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ a-zA-Z0-9_-]//g'`; do
      _bitbake_targets="$_bitbake_targets ${img}${_sufx}"
    done
  done
  if [ -z "$_bitbake_targets" ]; then
    # Autodetection failed.
    echo "ERROR: can't detect build targets. Check that REFKIT_CI_*_TARGETS defined in your configs."
    exit 1
  fi
else
  _bitbake_targets="$BUILD_TARGET"
fi

if [ ! -z ${JOB_NAME+x} ]; then
  # CI run: save output to log file
  LOG=$WORKSPACE/bitbake-${TARGET_MACHINE}-${CI_BUILD_ID}.log
  bitbake ${_bitbake_targets} 2>&1 | tee -a $LOG
else
  bitbake ${_bitbake_targets}
fi

if [ ! -z ${JOB_NAME+x} ]; then
  # in CI run only:
  # #############
  # Push buildhistory into job-machine-specific branch in the master buildhistory
  pushd ${BUILDHISTORY_TMP}
  BUILDHISTORY_TAG="${JOB_NAME}/${CI_BUILD_ID}/${CI_GIT_COMMIT}/${TARGET_MACHINE}"
  git tag -a -m "Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) of ${JOB_NAME} for ${TARGET_MACHINE}" -m "Built from Git revision ${CI_GIT_COMMIT}" ${BUILDHISTORY_TAG} refs/heads/${BUILDHISTORY_BRANCH}

  git push origin refs/tags/${BUILDHISTORY_TAG}:refs/tags/${BUILDHISTORY_TAG}
  # push branch might fail if multiple concurent jobs running for this branch.
  # That's ok, as most important part is stored under tag.
  git push origin refs/heads/${BUILDHISTORY_BRANCH}:refs/heads/${BUILDHISTORY_BRANCH} || true
  popd

  # #############
  # Create testinfo data for CI tester session
  set +e
  REFKIT_CI_TEST_RUNS=`grep REFKIT_CI_TEST_RUNS= ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ ,.a-zA-Z0-9_-]//g'`
  if [ -n "$REFKIT_CI_TEST_RUNS" ]; then
    for row in $REFKIT_CI_TEST_RUNS; do
      echo $row >> ${WORKSPACE}/${TARGET_MACHINE}.testinfo.csv
    done
  else
    # No automatic testing targets found
    echo -n "" > ${WORKSPACE}/${TARGET_MACHINE}.testinfo.csv
  fi
  set -e
fi
