#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11/24/2023

adb_file=`pwd`"/adb-utils.sh"
source $adb_file

suffix=`date +%d-%m-%Y`
id=`date +%s`

while [ "$#" -gt 0 ]
do
    case "$1" in
        --suffix)
            shift; suffix="$1"; shift;
            ;;
        --id)
            shift; id="$1"; shift;
            ;;
        -*) 
            echo "ERROR: Unknown option $1"
    esac
done

run_speedtest(){
    cmd="python ./v2/run_speedtest.py $1"
    run=`( $cmd )`
    if [ $? -ne 0 ]
    then
        myprint "Speedtest Failed"
    else
        if [[ "$run" == "DATA_EXCEEDED" ]];then
            myprint "Speedtest Skipped"
        else 
            myprint "Speedtest Success"
        fi
    fi
}

network_type=`get_network_type`
network_ind=`echo $network_type | cut -f 1 -d "_"`
network_ind=`echo "$network_ind// /-"`
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
testId="${id}_${network_ind}"
output_path="${res_folder}/speedtest-$testId.json"

if [[ "$network_ind" == "WIFI" ]];
then
    args="$network_ind $output_path"
    run_speedtest "$args"
else
    subscriptions_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/subscriptions.txt"
    simNum=`su -c cat $subscriptions_file | grep -n $network_ind | cut -f1 -d:`
    logFile=".last_mobile_speedtest_$simNum"
    if [ -f $logFile ]
    then
        log=`cat $logFile`
        args="$network_ind $output_path $logFile $log"
        run_speedtest "$args"
    else
        args="$network_ind $output_path $logFile"
        run_speedtest "$args"
    fi
fi

# if [ -f $logFile ]
#     lastMobSTest=`cat $logFile`
#     var=( $(echo ${d} | awk '{print $1,$2,$3}') )
#     last_test_tp="${var[0]}"
#     current_tp=`date +%s`
#     let "time_elapsed_since_last = current_tp-last_test_tp"
#     if [ $time_elapsed_since_last -lt 86400 ];
#     then
#         bytesUsedToday="${var[1]}"
#         # check threshold 
#     else
#         run_speedtest
#         # overwrite .last_mobile_speedtest 
#     fi
# fi

# testId="${id}_${network_ind}"
# res_folder="speedtest-cli-logs/${suffix}"
# mkdir -p $res_folder
# speedtest-cli --json > "${res_folder}/speedtest-$testId.json"
# gzip "${res_folder}/speedtest-$testId.json"

