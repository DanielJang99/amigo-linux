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
    speedtest_output=`speedtest-cli --json`
    if [ $? -eq 0 ]
    then
        echo $speedtest_output > "${res_folder}/speedtest-$testId.json" 
    else 
        node ./speed-cloudflare-cli/cli.js 1>"${res_folder}/speedtest-cloudflare-$testId.txt" 2>/dev/null 
    fi
}

network_type=`get_network_type`
network_ind=`echo $network_type | cut -f 1 -d "_"`
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
testId="${id}_${network_ind}"
# output_path="${res_folder}/speedtest-$testId.json"

if [[ "$network_ind" == "WIFI" ]];
then
    run_speedtest
    # args="$network_ind $output_path"
    # run_speedtest "$args"
elif [[ "$network_ind" == "sim"* ]];then
    skipping="false"
    mobile_today_file="./data/mobile/"$suffix".txt"		
	if [ -f $mobile_today_file ] 
	then 
		mobile_data=`cat $mobile_today_file`
        if [ $mobile_data -gt 500000000 ]; then
            skipping="true"
        fi
	fi	
    if [[ $skipping == "false" ]]; then
        run_speedtest
    fi
else
    skipping="false"
    esim_today_file="./data/airalo/"$suffix".txt"		
	if [ -f $esim_today_file ] 
	then 
		esim_data=`cat $esim_today_file`
        if [ $esim_data -gt 500000000 ]; then
            skipping="true"
        fi
	fi	
    if [[ $skipping == "false" ]]; then
        run_speedtest
    fi
fi
