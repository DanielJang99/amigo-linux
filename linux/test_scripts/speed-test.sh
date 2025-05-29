#!/bin/bash
## NOTE:  MTR adapted for Linux containers
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-05-29

# import util file
DEBUG=1
util_file=`pwd`"/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

run_speedtest(){
    # Ookla Speedtest
    test_start_time=`date +%s`
    speedtest_output=`speedtest-cli --json`
    if [ $? -eq 0 ]
    then
        test_end_time=`date +%s`
        duration=$((test_end_time - test_start_time))
        echo $speedtest_output > "${res_folder}/ookla-$test_start_time-$network_ind.json"
        myprint "Ookla Speedtest start: $test_start_time, end: $test_end_time, duration: $duration seconds"
    else
        myprint "Ookla Speedtest failed"
    fi

    # Cloudflare Speedtest
    test_start_time=`date +%s`
    cf_speedtest_output=`node ./test_scripts/speed-cloudflare-cli/cli.js 2>/dev/null`
    if [ $? -eq 0 ]
    then
        test_end_time=`date +%s`
        duration=$((test_end_time - test_start_time))
        echo $cf_speedtest_output > "${res_folder}/cloudflare-$test_start_time-$network_ind.txt"
        myprint "Cloudflare Speedtest start: $test_start_time, end: $test_end_time, duration: $duration seconds"
    else
        myprint "Cloudflare Speedtest failed"
    fi
}


# input
if [ $# -eq 2 ]
then 
	suffix=$1
	ts=$2
else 
	suffix=`date +%d-%m-%Y`
	ts=`date +%s`
fi 

network_type=$(check_network_status)
network_ind=$(echo "$network_type" | cut -f1 -d"_")
testId="${ts}_${network_ind}"
# folder organization
res_folder="./results/speedtest-cli-logs/${suffix}/${ts}"
mkdir -p $res_folder

test_start_time=`date +%s`
run_speedtest
test_end_time=`date +%s`
test_duration=$((test_end_time - test_start_time))
myprint "Speedtest-cli completed in $test_duration seconds"
