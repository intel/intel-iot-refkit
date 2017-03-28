#!/bin/bash -xeu
# publish-project.sh: Publish build results for specific layer project
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

create_remote_dirs () {
        _base=$1
        _dir=$2
        tmp_dir=`mktemp -d`
        pushd $tmp_dir
        echo "on base: ${_base} create dir: ${_dir}"
        mkdir -p ${_dir}
        rsync -av --ignore-existing --chmod=D755 ./ ${_base}/
        popd
        rm -fr $tmp_dir
}

create_swupd_links () {
  # create symlinks from update dir to builds dir
  _streamdir_www=$1
  _streamdir=$2
  _stream=$3

  _verdir=`ls -d ${_streamdir_www}/[0-9]*`
  _version=`basename $_verdir`
  _layer=`echo ${JOB_NAME} | sed 's/_[^_]*$//'`
  _updir=${_layer}/builds/${TARGET_MACHINE}/${_stream}

  tmp_dir=`mktemp -d`
  pushd $tmp_dir
  mkdir -p $_updir
  # add number link and version link which points to version/ under 'latest'
  ln -vsf ../../../../../builds/${JOB_NAME}/${CI_BUILD_ID}/swupd/${TARGET_MACHINE}/${_stream}/${_version} $_updir/$_version
  ln -vsf ../../../../../builds/${JOB_NAME}/latest/swupd/${TARGET_MACHINE}/${_stream}/version $_updir/version
  rsync -av --ignore-existing --chmod=D755 ./ ${_RSYNC_DEST_UPD}
  popd
  rm -fr $tmp_dir
}

# Catch errors in pipelines
set -o pipefail

_RSYNC_DEST=${RSYNC_PUBLISH_DIR}/builds/${JOB_NAME}/${CI_BUILD_ID}
_RSYNC_DEST_UPD=${RSYNC_PUBLISH_DIR}/updates

cd $WORKSPACE/build

_BRESULT=tmp-glibc
_DEPL=${_BRESULT}/deploy

# create publishing destination structure and copy
create_remote_dirs ${RSYNC_PUBLISH_DIR}/builds ${JOB_NAME}/${CI_BUILD_ID}
[ -d ${_DEPL}/images ] && create_remote_dirs ${_RSYNC_DEST} images && rsync -avS --exclude=README_-_DO_NOT_DELETE_FILES_IN_THIS_DIRECTORY.txt ${_DEPL}/images/${TARGET_MACHINE} ${_RSYNC_DEST}/images/
[ -d ${_DEPL}/licenses ] && create_remote_dirs ${_RSYNC_DEST} licenses && rsync -az --ignore-existing ${_DEPL}/licenses ${_RSYNC_DEST}/
[ -d ${_DEPL}/sources ] && create_remote_dirs ${_RSYNC_DEST} sources && rsync -av --ignore-existing ${_DEPL}/sources ${_RSYNC_DEST}/
[ -d ${_DEPL}/tools ] && create_remote_dirs ${_RSYNC_DEST} tools && rsync -av --ignore-existing ${_DEPL}/tools ${_RSYNC_DEST}/

# If produced, publish swupd repo to build directory.
# It will be published to real update location during build finalize steps
if [ -d ${_DEPL}/swupd/${TARGET_MACHINE} ]; then
    _jobtype=`echo ${JOB_NAME} | awk -F'_' '{print $NF}'`
    for s_dir in `find ${_DEPL}/swupd/${TARGET_MACHINE} -maxdepth 2 -name www -type d`; do
        i_dir=`dirname $s_dir`
        i_name=`basename $i_dir`
        # pre-create destination directories
        mkdir -p .swupd/swupd/${TARGET_MACHINE}/$i_name
        rsync -av --ignore-existing .swupd/swupd ${_RSYNC_DEST}/
        rm -rf .swupd
        rsync -av $s_dir/* ${_RSYNC_DEST}/swupd/${TARGET_MACHINE}/$i_name/
        if [ "$_jobtype" = "master" ]; then
            create_swupd_links $s_dir $i_dir $i_name
        fi
    done
fi

if [ -d ${_DEPL}/sdk ]; then
    # run eSDK publish script with destination set to sdk-data/TARGET_MACHINE/
    # script name is dynamic, used via wildard. NB! works while there is only one sdk/*-toolchain-ext*.sh
    ${WORKSPACE}/openembedded-core/scripts/oe-publish-sdk ${_DEPL}/sdk/*-toolchain-ext*.sh ${_DEPL}/sdk-data/${TARGET_MACHINE}/
    # publish installer .sh file to sdk/
    create_remote_dirs ${_RSYNC_DEST} sdk/${TARGET_MACHINE}
    rsync -av ${_DEPL}/sdk/*.sh ${_RSYNC_DEST}/sdk/${TARGET_MACHINE}/
fi
if [ -d ${_DEPL}/sdk-data/${TARGET_MACHINE} ]; then
    # publish sdk-data/ without -v option, avoiding logging massive list
    create_remote_dirs ${_RSYNC_DEST} sdk-data
    rsync -a ${_DEPL}/sdk-data/${TARGET_MACHINE} ${_RSYNC_DEST}/sdk-data/
fi
if [ -d ${_DEPL}/testsuite ]; then
    create_remote_dirs ${_RSYNC_DEST} testsuite/${TARGET_MACHINE}
    rsync -av ${_DEPL}/testsuite/* ${_RSYNC_DEST}/testsuite/${TARGET_MACHINE}/
fi
# publish isafw reports
if [ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw*' -print -quit)" ]; then
    create_remote_dirs ${_RSYNC_DEST} isafw/${TARGET_MACHINE}/
    rsync -avz ${_BRESULT}/log/isafw-report*/* ${_RSYNC_DEST}/isafw/${TARGET_MACHINE}/ --exclude internal
fi

LOG="$WORKSPACE/bitbake-${TARGET_MACHINE}-${CI_BUILD_ID}.log"
if [ -f "${LOG}" ]; then
    xz -v -k ${LOG}
    rsync -avz ${LOG}* ${_RSYNC_DEST}/
fi

if [ -d sstate-cache ]; then
  if [ ! -z ${BUILD_CACHE_DIR+x} ]; then
    if [ -d ${BUILD_CACHE_DIR}/sstate ]; then
      # populate shared sstate from local sstate:
      _src=sstate-cache
      _dst=${RSYNC_PUBLISH_DIR}/bb-cache/sstate
      find ${_src} -mindepth 1 -maxdepth 1 -type d -exec rsync -a --ignore-existing {} ${_dst}/ \;
    fi
  fi
fi

## for debugging signatures: publish stamps
if [ -d ${_BRESULT}/stamps ]; then
    create_remote_dirs ${_RSYNC_DEST} .stamps/${TARGET_MACHINE}/
    rsync -a ${_BRESULT}/stamps/* ${_RSYNC_DEST}/.stamps/${TARGET_MACHINE}/
fi
if [ -d ${_BRESULT}/buildstats ]; then
    create_remote_dirs ${_RSYNC_DEST} .buildstats/${TARGET_MACHINE}
    rsync -az ${_BRESULT}/buildstats/* ${_RSYNC_DEST}/.buildstats/${TARGET_MACHINE}/
fi
# Copy detailed build logs
# Include symlinks to avoid massive amount of "skipping non-regular file"
# lines in the rsyncd server system-level log
if [ -d ${_BRESULT}/work ]; then
    create_remote_dirs ${_RSYNC_DEST} detailed-logs/${TARGET_MACHINE}/
    rsync -qzrl --prune-empty-dirs --include "log.do_*" --include "*/" --exclude "*" ${_BRESULT}/work*/* ${_RSYNC_DEST}/detailed-logs/${TARGET_MACHINE}/
fi

# Create latest symlink locally and rsync it to parent dir of publish dir
ln -vsf ${CI_BUILD_ID} latest
rsync -lv latest ${_RSYNC_DEST}/../

cd $WORKSPACE
_tar_file=`mktemp --suffix=.tar.gz`
tar czf ${_tar_file} . \
        --transform "s,^\.,${JOB_NAME}-${CI_BUILD_ID},S" \
        --exclude 'bitbake*.log*' --exclude 'build' \
        --exclude 'buildhistory' --exclude 'refkit_ci*' \
        --exclude '.git' --exclude '*.testinfo.csv'
rsync -av --chmod=F644 ${_tar_file} ${_RSYNC_DEST}/${JOB_NAME}-${CI_BUILD_ID}.tar.gz
rm -f ${_tar_file}
