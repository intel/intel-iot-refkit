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

# bitbake started to depend on a locale with UTF-8 support
# when migrating to Python3.
export LC_ALL=en_US.UTF-8

cd $WORKSPACE

# use +u to avoid exit caused by unbound variables use in init scripts
set +u
# note, BUILD_DIR is also undef in CI case, but is set in local-build case.
source refkit-init-build-env ${BUILD_DIR}
set -u

if [ ! -z ${JOB_NAME+x} ]; then
  # in CI: run post-build oe-selftests using development-mode settings in auto.conf
  # we can't use full auto.conf of builder, oe-selftest does not like buildhistory=ON
  echo "include conf/distro/include/refkit-development.inc" > ${WORKSPACE}/build/conf/auto.conf
  _tests=`grep REFKIT_CI_POSTBUILD_SELFTESTS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ .a-zA-Z0-9_-]//g'`
  if [ -n "$_tests" ]; then
    oe-selftest --run-tests ${_tests}
  fi
fi
