#!/bin/bash

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	echo "Trapped CTRL-C"
	for pid in `ps aux | grep -w "muzeel-test.sh" | grep -v "grep" | awk '{print $2}'`
	do 
		kill -9 $pid
	done
	exit -1 
}

# main 
N=`wc -l muzeel-urls.txt | cut -f 1 -d " "`
target_url=0
suffix=`date +%d-%m-%Y`
curr_id=`date +%s`
iface="wlan0"
num_increase=5
force_mobile="false"
echo "TestID: $curr_id"
while [ $target_url -le $N ] 
do 
	if [ $force_mobile == "true" ]
	then
		./muzeel-test.sh  --suffix $suffix --id $curr_id --target $target_url --mobile    # --pcap  (avoid CPU load)
	else  
		./muzeel-test.sh  --suffix $suffix --id $curr_id --target $target_url             # --pcap  (avoid CPU load)
	fi 
	let "target_url += num_increase" 
done
