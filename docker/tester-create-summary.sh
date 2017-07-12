#!/bin/bash -ue
#
# tester-create-summary.sh: tester creates summary information
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

declare -i num_total=0 num_skipped=0 num_na=0 num_failed=0 num_error=0
_image=$1
_device=$2
_reports_basename=$3
_num_masked=$4

# create piece of summary for composing email notification
_reports=`ls ${_reports_basename}*.xml`
num_na=$_num_masked
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
echo "${_image}"
[ -n "$_device" ] && echo "  Device: ${_device}"
echo "  Total:$num_total  Pass:$num_passed  Fail:$num_failed  Skip:$num_skipped  Error:$num_error  N/A:$num_na"
if [ $num_total -gt 0 ]; then
    run_rate=$((100*run_total/num_total))
    pass_rate_of_total=$((100*num_passed/num_total))
    pass_rate_of_exec=$((100*num_passed/run_total))
    echo "  Run rate:${run_rate}%  Pass rate of total:${pass_rate_of_total}%  Pass rate of exec:${pass_rate_of_exec}%"
fi
echo "-------------------------------------------------------------------"
