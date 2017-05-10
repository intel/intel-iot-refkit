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

# This script relies on workspace which is cleaned via jenkins method

# function to test an image with QEMU, call point in testimg() function
test_qemu() {
  wget ${_WGET_OPTS} ${CI_BUILD_URL}/images/${MACHINE}/ovmf.qcow2

  # Make port numbers and mac address that won't collide with anything
  PID=$$
  RAND_PORT=$((PID%5000)) # Make a number between 0-4999
  UNIQUE_MAC=$((100000+(PID%900000))) # Make a number with 6 digits
  PORT1=$((10000+RAND_PORT))
  PORT2=$((15000+RAND_PORT))
  while netstat -tna | grep $PORT1 > /dev/null; do
    ((PORT1++))
  done
  while netstat -tna | grep $PORT2 > /dev/null; do
    ((PORT2++))
  done
  QEMU_MAC=52:54:00:${UNIQUE_MAC:0:2}:${UNIQUE_MAC:2:2}:${UNIQUE_MAC:4:2}

  nohup ./run-qemu.exp $PORT1 $PORT2 $QEMU_MAC $FILENAME &>run_qemu.log &
  QEMU_PID=$!

  # Test when QEMU has booted and added SSH key
  ssh_exit_code=1
  ssh_retry=0
  while [ ! "$ssh_exit_code" = 0 ]; do
    if [ "$ssh_retry" = 30 ]; then
      TEST_EXIT_CODE=1
      return 1
    fi
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -o BatchMode=yes root@127.0.0.1 -p $PORT1 ls
    ssh_exit_code=$?
    ((ssh_retry++))
    sleep 2
  done

  python iottest/runtest.py \
  -f iottest/testplan/image-testplan.manifest \
  -m intel-corei7-64 -t 127.0.0.1:$PORT1 -s 10.0.2.2 --xunit .

  TEST_EXIT_CODE=$?
  kill $QEMU_PID
}

# function to test one image, see call point below.
testimg() {
  declare -i num_masked=0 num_total=0 num_skipped=0 num_na=0 num_failed=0 num_error=0
  _IMG_NAME=$1
  TEST_SUITE_FILE=$2
  TEST_CASES_FILE=$3

  # Get test suite
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${_IMG_NAME}/${TEST_SUITE_FILE}
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${_IMG_NAME}/${TEST_CASES_FILE}
  tar -xzf ${TEST_SUITE_FILE}
  tar -xzf ${TEST_CASES_FILE} -C iottest/

  # Copy local WLAN settings to iottest over example file and chmod to readable
  _WLANCONF=./iottest/oeqa/runtime/connectivity/wifi/files/config.ini
  cp $HOME/.config.ini.wlan ${_WLANCONF}
  chmod 644 ${_WLANCONF}

  FILENAME=${_IMG_NAME}-${MACHINE}-${CI_BUILD_ID}.wic
  set +e
  wget ${_WGET_OPTS} ${CI_BUILD_URL}/images/${MACHINE}/${FILENAME}.bmap
  wget ${_WGET_OPTS} ${CI_BUILD_URL}/images/${MACHINE}/${FILENAME}.xz -O - | unxz - > ${FILENAME}
  if [ ! -s ${FILENAME} ]; then
    wget ${_WGET_OPTS} ${CI_BUILD_URL}/images/${MACHINE}/${FILENAME}.zip
    if [ -s ${FILENAME}.zip ]; then
      unzip ${FILENAME}.zip
    else
      echo "ERROR: No file ${FILENAME}.xz or ${FILENAME}.zip found, can not continue."
      exit 1
    fi
  fi
  set -e

  if [ ! -z ${TEST_DEVICE+x} ]; then
    DEVICE="$TEST_DEVICE"
  elif [ ! -z ${JOB_NAME+x} ]; then
    DEVICE=`echo ${JOB_NAME} | awk -F'_' '{print $2}'`
  else
    DEVICE="unconfigured"
  fi

  # Remove incompatible tests for the DUT from image-testplan.manifest
  MASKFILE=./iottest/testplan/${DEVICE}.mask
  MANIFEST=./iottest/testplan/image-testplan.manifest
  set +e # 'grep -cFwf' exit code isn't 0 if no tests get masked so ignore it
  num_masked=$(grep -cFwf ${MASKFILE} ${MANIFEST})
  set -e
  grep -Fvxf ${MASKFILE} ${MANIFEST} > tmp && mv tmp ${MANIFEST}

  # Execute with +e to make sure that possibly created log files get
  # renamed, archived, published even when DAFT, QEMU or some of renaming fails
  set +e
  if [ "${DEVICE}" = "qemu" ]; then
    test_qemu
  else
    daft ${DEVICE} ${FILENAME} --record
    TEST_EXIT_CODE=$?
  fi

  # delete symlinks, these point outside of local set and are useless
  find . -type l -print -delete
  # modify names inside TEST-*.xml files to contain device and img_name
  # as these get shown in same xUnit results table in Jenkins
  sed -e "s/name=\"oeqa/name=\"${DEVICE}.${_IMG_NAME}.oeqa/g" -i TEST-*.xml
  # rename files to contain device and img_name
  rename TEST- TEST-${DEVICE}.${_IMG_NAME}. TEST-*.xml
  rename .log .${DEVICE}.${_IMG_NAME}.log *.log
  # create summary file to be used in email notification sending
  _reports=`ls TEST-${DEVICE}.${_IMG_NAME}.*.xml`
  num_na=$num_masked
  for _r in $_reports; do
    _s=`grep 'testsuite errors=' $_r |tr -d '<>' |sed 's/testsuite//g'`
    eval $_s
    num_error+=${errors}
    num_failed+=${failures}
    num_skipped+=${skipped}
    num_total+=${tests}
  done
  num_passed=$((num_total - num_error - num_failed - num_skipped))
  run_total=$((num_passed + num_failed))
  # passing data from here to Jenkinsfile works through file in workspace:
  sumfile=results-summary-${DEVICE}.${_IMG_NAME}.log
  echo "Image: ${FILENAME}" > $sumfile
  echo "  Device: ${DEVICE}" >> $sumfile
  echo "  Total:$num_total  Pass:$num_passed  Fail:$num_failed  Skip:$num_skipped  Error:$num_error  N/A:$num_na" >> $sumfile
  if [ $num_total -gt 0 ]; then
    run_rate=$((100*run_total/num_total))
    pass_rate_of_total=$((100*num_passed/num_total))
    pass_rate_of_exec=$((100*num_passed/run_total))
    echo "  Run rate:${run_rate}%  Pass rate of total:${pass_rate_of_total}%  Pass rate of exec:${pass_rate_of_exec}%" >> $sumfile
  fi
  echo "-------------------------------------------------------------------" >> $sumfile
  set -e

  return ${TEST_EXIT_CODE}
}

# Start, document env.vars in build log
env |sort

_WGET_OPTS="--no-verbose --no-proxy"
CI_BUILD_URL=${COORD_BASE_URL}/builds/${JOB_NAME}/${CI_BUILD_ID}
TEST_SUITE_FOLDER_URL=${CI_BUILD_URL}/testsuite/${MACHINE}

# get necessary params from testinfo.csv file written to tester workspace
# by code in Jenkinsfile. We have just one line for this tester session.
while IFS=, read _img _tsuite _tdata _mach _dev
do
  [ "${_mach}" = "${MACHINE}" ] && testimg ${_img} ${_tsuite} ${_tdata}
done < testinfo.csv
