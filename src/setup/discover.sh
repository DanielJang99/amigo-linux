#!/bin/bash

for device in `adb devices | grep -v List | cut -f 1`
	do
	ip=`adb -s $device shell ifconfig wlan0 | grep "\." | grep -v packets | awk '{print $2}' | cut -f 2 -d ":"`
	uid=`timeout 5 ssh -oStrictHostKeyChecking=no -i id_rsa_mobile -p 8022 $ip "termux-telephony-deviceinfo" | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
	echo -e "$device\t$ip\t$uid"
done 
