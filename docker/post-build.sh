#!/bin/bash -xeu
# build-project.sh: Post-build steps
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

# bitbake started to depend on a locale with UTF-8 support
# when migrating to Python3.
export LC_ALL=en_US.UTF-8

cd $WORKSPACE

# use +u to avoid exit caused by unbound variables use in init scripts
set +u
# note, BUILD_DIR is also undef in CI case, but is set in local-build case.
source oe-init-build-env ${BUILD_DIR}
set -u

# create auto.conf using functions in build-common-util.sh
auto_conf_common

auto_conf_testsdk

# post-build testing builds images but only .wic is sufficient
# (default in IMAGE_FSTYPES). We skip compression and bmap formats
# to optimize testing time
echo "REFKIT_VM_IMAGE_TYPES = \"\"" >> conf/auto.conf

export BUILD_ID=${CI_BUILD_ID}
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE BUILD_ID"

_esdks=""
for esdk in `grep REFKIT_CI_ESDK_TEST_TARGETS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ a-zA-Z0-9_-]//g'`; do
  _esdks="$_esdks ${esdk}:do_testsdkext"
done
bitbake ${_esdks}

_tests=`grep REFKIT_CI_POSTBUILD_SELFTESTS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ .a-zA-Z0-9_-]//g'`
if [ -n "$_tests" ]; then
  oe-selftest --run-tests ${_tests}
fi
