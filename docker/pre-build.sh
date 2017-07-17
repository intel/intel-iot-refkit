#!/bin/bash -xeu
# pre-build.sh: Pre-build steps
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

. $(dirname $0)/build-common-util.sh

# Catch errors in pipelines
set -o pipefail

# bitbake started to depend on a locale with UTF-8 support
# when migrating to Python3.
export LC_ALL=en_US.UTF-8

cd $WORKSPACE

# document env.vars in build log
env |sort

# use +u to avoid exit caused by unbound variables use in init scripts
set +u
# note, BUILD_DIR is also undef in CI case, but is set in local-build case.
source oe-init-build-env ${BUILD_DIR}
set -u

# create auto.conf using functions in build-common-util.sh
auto_conf_common
auto_dump

export BUILD_ID=${CI_BUILD_ID}
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE BUILD_ID"

# use bitbake -e for variables parsing, then pick REFKIT_CI part
bitbake -e >bb_e_out 2>bb_e_err || (cat bb_e_err && false)
grep -E "^REFKIT_CI" bb_e_out > ${WORKSPACE}/refkit_ci_vars || true

_tests=`grep REFKIT_CI_PREBUILD_SELFTESTS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ .a-zA-Z0-9_-]//g'`
if [ -n "$_tests" ]; then
  oe-selftest --run-tests ${_tests}
fi
# build/ should not pollute next stages: don't delete, it has test results
mv -f ${WORKSPACE}/build ${WORKSPACE}/build.pre
