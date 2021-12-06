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
	if [ $# -eq 1 ] 
	then 
		echo "Using list: $1"
		ip_list=$1
	else 
		echo "Discovering connected devices..."
		#sudo nmap -p 8022 192.168.1.0/24 > ".nmap-log"
		cat .nmap-log  | grep -B 4 "open" | grep report | awk '{print $NF}' > "nmap-based-ip-list"	
		ip_list="nmap-based-ip-list"
	fi 
	echo "Loading IPs from list $ip_list" 
	num_ips=0
	while read line
	do 
		ip[$num_ips]=$line
		let "num_ips++"
	done < "$ip_list"
	for((i=0; i<num_ips; i++))
	do 
		curr_ip=${ip[$i]}
		uid=`timeout 5 ssh -oStrictHostKeyChecking=no -i id_rsa_mobile -p 8022 $curr_ip "termux-telephony-deviceinfo" | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
		echo -e "$curr_ip\tN/A\t$uid"
	done 
fi 
