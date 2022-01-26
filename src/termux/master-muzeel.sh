#!/bin/bash

N=`wc -l muzeel-urls.txt | cut -f 1 -d " "`
target_url=0
suffix=`date +%d-%m-%Y`
curr_id=`date +%s`
iface="wlan0"
while [ $target_url -le $N ] 
do 
	./muzeel-test.sh  --suffix $suffix --id $curr_id --iface $iface --pcap --target $target_url
	let "target_url += 2" 
done
