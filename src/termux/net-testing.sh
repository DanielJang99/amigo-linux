#!/bin/bash
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

# test multiple webages 
./web-test.sh  --suffix $suffix --id $t_s --iface $iface

# video testing
# TODO 
