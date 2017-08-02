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

publish () {
  # publish results of one build config
  _BRESULT=$1
_DEPL=${_BRESULT}/deploy
_bresult_suffix=`echo ${_BRESULT} | sed 's/\.\/tmp-//'`
_RSYNC_DEST=${_RSYNC_DEST_BASE}/${_bresult_suffix}

# create publishing destination structure and copy
create_remote_dirs ${RSYNC_PUBLISH_DIR}/builds ${JOB_NAME}/${CI_BUILD_ID}
# no uses for stored plain .wic files, skip storing on server, saving big part of space and transfer time
[ -d ${_DEPL}/images ] && create_remote_dirs ${_RSYNC_DEST} images && rsync -avS --exclude '*.wic' ${_DEPL}/images/${TARGET_MACHINE} ${_RSYNC_DEST}/images/
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
# publish isafw reports and logs
if [ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw*' -print -quit)" ]; then
    create_remote_dirs ${_RSYNC_DEST} isafw/${TARGET_MACHINE}/
    if [ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw-logs' -print -quit)" ]; then
        rsync -avz ${_BRESULT}/log/isafw-logs/* ${_RSYNC_DEST}/isafw/${TARGET_MACHINE}/ --exclude internal
    fi
    # isafw reports are created in timestamp-named subdirs like isafw-report_20170409070145/
    if [ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw-report*' -print -quit)" ]; then
        rsync -avz ${_BRESULT}/log/isafw-report*/* ${_RSYNC_DEST}/isafw/${TARGET_MACHINE}/ --exclude internal
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
}

# Catch errors in pipelines
set -o pipefail

_RSYNC_DEST_BASE=${RSYNC_PUBLISH_DIR}/builds/${JOB_NAME}/${CI_BUILD_ID}
_RSYNC_DEST_UPD=${RSYNC_PUBLISH_DIR}/updates

cd $WORKSPACE/build
for _bresult in `find . -maxdepth 1 -type d -name 'tmp-*glibc'`; do
    publish ${_bresult}
done

LOG=$WORKSPACE/$CI_LOG
if [ -f "${LOG}" ]; then
    xz -v -k ${LOG}
    rsync -avz ${LOG}* ${_RSYNC_DEST_BASE}/
fi

# Create latest symlink locally and rsync it to parent dir of publish dir
ln -vsf ${CI_BUILD_ID} latest
rsync -lv latest ${_RSYNC_DEST_BASE}/../

# create clean tarball of source, leaving out .git* and parts created by build and test stages
cd $WORKSPACE
_tar_file=`mktemp --suffix=.tar.gz`
tar czf ${_tar_file} . \
        --transform "s,^\.,${JOB_NAME}-${CI_BUILD_ID},S" \
        --exclude 'bitbake*.log*' --exclude 'build' --exclude 'build.pre' \
        --exclude 'buildhistory*' --exclude 'refkit_ci*' \
        --exclude '.git*' --exclude '*.testinfo.csv'
rsync -av --remove-source-files --chmod=F644 ${_tar_file} ${_RSYNC_DEST_BASE}/${JOB_NAME}-${CI_BUILD_ID}.tar.gz
