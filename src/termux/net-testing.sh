#!/bin/bash

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# folder organization
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
if [ $# -eq 2 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
fi  

# test multiple webages 
turn_device_on
#./web-test.sh  --suffix $suffix --id $t_s --iface $iface

# video testing
./youtube-test.sh --suffix $suffix --id $t_s --iface $iface

# save battery, screen off 
turn_device_off
# run a speedtest 
echo "[`date`] speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# run NYU stuff 
# TODO 

# run multiple MTR
./mtr.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s

# QUIC test? 
# TODO 
