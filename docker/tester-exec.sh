#!/bin/bash -xue
#
# tester-exec.sh: test one image on a tester
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
#

# function to test one image, see call point below.
testimg() {
  _IMG_NAME=$1
  TEST_SUITE_FILE=$2
  TEST_CASES_FILE=$3
  _IMG_NAME_MACHINE=${_IMG_NAME}-${MACHINE}

  # Get test suite
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${_IMG_NAME}/${TEST_SUITE_FILE}
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${_IMG_NAME}/${TEST_CASES_FILE}
  tar -xzf ${TEST_SUITE_FILE}
  tar -xzf ${TEST_CASES_FILE} -C iottest/

  # Copy local WLAN settings to iottest over example file and chmod to readable
  _WLANCONF=./iottest/oeqa/runtime/sanity/files/config.ini
  cp $HOME/.config.ini.wlan ${_WLANCONF}
  chmod 644 ${_WLANCONF}

  # Get image(s)
  if [ "${MACHINE}" = "edison" ]; then
    # Workaround for the wifi test bug -- not enabled, left here for possible future activation
    #sed -i "s/oeqa.runtime.sanity.comm_wifi_connect/#oeqa.runtime.sanity.comm_wifi_connect/g" iottest/testplan/iottest.manifest
    EDISON_TAR_FILENAME=${_IMG_NAME_MACHINE}.toflash.tar.bz2
    TEST_IMG_URL=${DIR_FULL_URL}/images/${MACHINE}/${EDISON_TAR_FILENAME}
    wget ${_WGET_OPTS} ${TEST_IMG_URL}
    tar -xf ${EDISON_TAR_FILENAME}
    mv toFlash/* .
    FILENAME=${_IMG_NAME_MACHINE}.ext4
  elif [ "${MACHINE}" = "beaglebone" ]; then
    FILE_DIR="${DIR_FULL_URL}/images/${MACHINE}"
    wget ${_WGET_OPTS} ${FILE_DIR}/MLO
    wget ${_WGET_OPTS} ${FILE_DIR}/u-boot.img
    wget ${_WGET_OPTS} ${FILE_DIR}/zImage
    wget ${_WGET_OPTS} ${FILE_DIR}/zImage-am335x-boneblack.dtb
    FILENAME=${_IMG_NAME_MACHINE}.tar.bz2
    wget ${_WGET_OPTS} ${FILE_DIR}/${FILENAME}

  else
    FN_BASE=${_IMG_NAME_MACHINE}-${CI_BUILD_ID}
    FILENAME=${FN_BASE}.wic
    FILENAME_BMAP=${FILENAME}.bmap
    FILENAME_XZ=${FILENAME}.xz
    FILENAME_ZIP=${FILENAME}.zip

    set +e
    wget ${_WGET_OPTS} ${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_BMAP}
    wget ${_WGET_OPTS} ${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_XZ} -O - | unxz - > ${FILENAME}
    if [ ! -s ${FILENAME} ]; then
      wget ${_WGET_OPTS} ${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_ZIP}
      if [ -s ${FILENAME_ZIP} ]; then
        unzip ${FILENAME_ZIP}
      else
        echo "ERROR: No file ${FILENAME_XZ} or ${FILENAME_ZIP} found, can not continue."
        exit 1
      fi
    fi
    set -e
  fi

  if [ ! -z ${TEST_DEVICE+x} ]; then
    DEVICE="$TEST_DEVICE"
  elif [ ! -z ${JOB_NAME+x} ]; then
    DEVICE=`echo ${JOB_NAME} | awk -F'_' '{print $2}'`
  else
    DEVICE="unconfigured"
  fi

  if [ "${DEVICE}" != "gigabyte" ]; then
    RECORD_ARG="--record"
  else
    RECORD_ARG=""
  fi

  # Remove incompatible tests for the DUT from image-testplan.manifest
  MASKFILE=./iottest/testplan/${DEVICE}.mask
  MANIFEST=./iottest/testplan/image-testplan.manifest
  set +e # 'grep -cFwf' exit code isn't 0 if no tests get masked so ignore it
  num_masked=$(grep -cFwf ${MASKFILE} ${MANIFEST})
  set -e
  grep -Fvxf ${MASKFILE} ${MANIFEST} > tmp && mv tmp ${MANIFEST}

  # Execute with +e to make sure that possibly created log files get
  # renamed, archived, published even when AFT or some of renaming fails
  set +e
  daft ${DEVICE} ${FILENAME} ${RECORD_ARG}
  AFT_EXIT_CODE=$?

  # modify names inside TEST-*.xml files to contain device and img_name
  # as these get shown in same xUnit results table in Jenkins
  sed -e "s/name=\"oeqa/name=\"${DEVICE}.${_IMG_NAME}.oeqa/g" -i TEST-*.xml
  # rename files to contain device and img_name
  rename TEST- TEST-${DEVICE}.${_IMG_NAME}. TEST-*.xml
  rename .log .${DEVICE}.${_IMG_NAME}.log *.log
  # create summary file to be used in email notification sending
  _reports=`ls TEST-${DEVICE}.${_IMG_NAME}.*.xml`
  num_total=0
  num_skipped=$((0+num_masked))
  num_failed=0
  num_error=0
  for _r in $_reports; do
    _s=`grep 'testsuite errors=' $_r |tr -d '<>' |sed 's/testsuite//g'`
    eval $_s
    num_error=$(( num_error + errors ))
    num_failed=$(( num_failed + failures ))
    num_skipped=$(( num_skipped + skipped ))
    num_total=$(( num_total + tests ))
  done
  num_passed=$(( num_total - num_error - num_failed - num_skipped ))
  run_total=$((num_passed + num_failed))
  # passing data from here to Jenkinsfile works through file in workspace:
  sumfile=results-summary-${DEVICE}.${_IMG_NAME}.log
  echo "Image: ${FILENAME}" > $sumfile
  echo "  Device: ${DEVICE}" >> $sumfile
  echo "  Total:$num_total  Pass:$num_passed  Fail:$num_failed  Skip:$num_skipped  Error:$num_error" >> $sumfile
  if [ $num_total -gt 0 ]; then
    run_rate=$((100*run_total/num_total))
    pass_rate_of_total=$((100*num_passed/num_total))
    pass_rate_of_exec=$((100*num_passed/run_total))
    echo "  Run rate:${run_rate}%  Pass rate of total:${pass_rate_of_total}%  Pass rate of exec:${pass_rate_of_exec}%" >> $sumfile
  fi
  echo "-------------------------------------------------------------------" >> $sumfile
  # combine artifacts into single file for easier download
  tar c --ignore-failed-read results* *.xml *.log | bzip2 -c9 > aft-results_${DEVICE}_${_IMG_NAME}_${TEST_SUITE_FILE}.tar.bz2
  set -e

  return ${AFT_EXIT_CODE}
}

# Start
# Note: this script relies on cleaned workspace (clean it via jenkins job config)

_WGET_OPTS="--no-verbose --no-proxy"

DIR_FULL_URL="$CI_BUILD_URL"
TEST_SUITE_FOLDER_URL="${DIR_FULL_URL}/testsuite/${MACHINE}/"

# document env.vars in build log
env |sort

# process testinfo file written to tester workspace by Jenkinsfile.
# Jenkinsfile sorts it all out, we have just one line for this tester session.
while IFS=, read _img _tsuite _tdata _mach
do
  [ "${_mach}" = "${MACHINE}" ] && testimg ${_img} ${_tsuite} ${_tdata}
done < testinfo.csv
