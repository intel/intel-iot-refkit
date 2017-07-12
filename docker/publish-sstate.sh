#!/bin/sh -xeu
#
# publish-project.sh: Publish local sstate into global sstate
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

cd $WORKSPACE/build

if [ -d sstate-cache ]; then
  if [ ! -z ${BUILD_CACHE_DIR+x} ]; then
    if [ -d ${BUILD_CACHE_DIR}/sstate ]; then
      # populate shared sstate from local sstate, show names for tracability
      _src=sstate-cache
      _dst=${RSYNC_PUBLISH_DIR}/bb-cache/sstate
      find ${_src} -mindepth 1 -maxdepth 1 -type d -exec rsync -a --info=name --ignore-existing {} ${_dst}/ \;
    fi
  fi
fi
