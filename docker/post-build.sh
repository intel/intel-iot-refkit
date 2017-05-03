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
source refkit-init-build-env ${BUILD_DIR}
set -u

# create auto.conf using functions in build-common-util.sh
auto_conf_common

export BUILD_ID=${CI_BUILD_ID}
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE BUILD_ID"

# Our post-build configuration should not require rebuilding.
_images=""
for img in `grep REFKIT_CI_BUILD_TARGETS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ a-zA-Z0-9_-]//g'`; do
  _images="$_images ${img}"
done
bitbake -S none ${_images}

# Check intel-linux specifically in addition to images, because it did
# rebuild at some point and even though bitbake-diffsigs should
# recurse to it, that's not guaranteed to work.
for target in intel-linux ${_images}; do
  if ! bitbake-diffsigs -t $target do_build; then
    echo "$target: nothing changed or bitbake-diffsigs failed"
  fi
done

_tests=`grep REFKIT_CI_POSTBUILD_SELFTESTS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ .a-zA-Z0-9_-]//g'`
if [ -n "$_tests" ]; then
  oe-selftest --run-tests ${_tests}
fi

# If something changed during the oe-selftest setup, we should (finally)
# have two signatures to compare here.
for target in intel-linux ${_images}; do
  if ! bitbake-diffsigs -t $target do_build; then
    echo "$target: nothing changed or bitbake-diffsigs failed"
  fi
done
