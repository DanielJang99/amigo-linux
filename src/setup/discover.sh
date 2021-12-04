#!/bin/bash
use_adb="false"
if [ $use_adb == "true" ] 
then 
	for device in `adb devices | grep -v List | cut -f 1`
		do
		ip=`adb -s $device shell ifconfig wlan0 | grep "\." | grep -v packets | awk '{print $2}' | cut -f 2 -d ":"`
		uid=`timeout 5 ssh -oStrictHostKeyChecking=no -i id_rsa_mobile -p 8022 $ip "termux-telephony-deviceinfo" | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
		echo -e "$ip\t$device\t$uid"
	done 
else 
	if [ $# -ne 1 ] 
	then 
		echo "ERROR. Without ADB please pass a list of IP addresses"
		exit -1 
	fi 
	num_ips=0
	while read line
	do 
		ip[$num_ips]=$line
		let "num_ips++"
	done < $1
	for((i=0; i<num_ips; i++))
	do 
		curr_ip=${ip[$i]}
		uid=`timeout 5 ssh -oStrictHostKeyChecking=no -i id_rsa_mobile -p 8022 $curr_ip "termux-telephony-deviceinfo" | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
		echo -e "$curr_ip\tN/A\t$uid"
	done 
fi 
