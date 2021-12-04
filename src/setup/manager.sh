#!/bin/bash
## Note: script to start experiment at N nodes

#check input 
if [ $# -ne 2 -a $# -ne 3 ] 
then 
	echo "USAGE: $0 <ip-file> <opt> [start/stop/prep/check/kill] <script>"
	exit -1 
fi 

# parameters
ip_file=$1       
opt=$2
ssh_key="id_rsa_mobile"      

# read IPs
num_devices=0
while read line 
do 
	ip=`echo "$line" | cut -f 1`
	ip_list[$num_devices]=$ip
	let "num_devices++"
done < $ip_file

# iterate on devices
for((i=0; i<num_devices; i++))
do 
	wifi_ip=${ip_list[$i]}
	if [ $opt == "start" ] 
	then 
		echo "Starting ./state-update.sh at $wifi_ip:8022"
		ssh -T -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip 'sh -c "cd mobile-testbed/src/termux/ && ./state-update.sh > log-state-update 2>&1 &"'
		#ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/termux/ && ./state-update.sh > \"logs/log-state-update-\"\`date +\%m-\\%d-\%y_\%H:\%M\`\".txt &"
	elif [ $opt == "stop" ] 
	then 
		echo "Stopping ./state-update.sh at $wifi_ip:8022"
		timeout 5 ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip 'sh -c "pkill -9 -f state-update"'
	elif [ $opt == "kill" ] 
	then 
		if [ $# -ne 3 ]
		then 
			exit -1 
		fi 
		script=$3
		#echo "Stopping $script at $wifi_ip:8022"
		echo "FIXME. Stopping videoconf-tester at $wifi_ip:8022"
		timeout 5 ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip 'sh -c "pkill -9 -f videoconf-tester"'
		#echo "ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip \'sh -c \"pkill -9 -f $script\"\'"
		#ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip 'sh -c "pkill -9 -f $script"'
	elif [ $opt == "check" ] 
	then
		echo "Checking phone at $wifi_ip:8022"
		timeout 5 ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "ps aux | grep bash | grep -v grep"
	elif [ $opt == "prep" ] 
	then
		echo "Prepping phone: $wifi_ip:8022"
		#echo "./check-update.sh $wifi_ip > logs/log-prepping-$wifi_ip 2>&1 &"
		./check-update.sh $wifi_ip > logs/log-prepping-$wifi_ip 2>&1 &
	else 
		echo "Command $opt not supported yet!"
	fi 
done
