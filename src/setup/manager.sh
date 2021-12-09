#!/bin/bash
## Note: script to start experiment at N nodes

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    echo "Trapped CTRL-C"
    exit -1
}

#check input 
if [ $# -ne 2 -a $# -ne 3 ] 
then 
	echo "USAGE: $0 <ip-file> <opt> [start/stop/reboot/prep/check/cron/test/kill] <script>"
	exit -1 
fi 

# parameters
ip_file=$1       
opt=$2
ssh_key="id_rsa_mobile"      
command_dur=10 

# read IPs
num_devices=1
while read line 
do 
	ip=`echo "$line" | cut -f 1`
	ip_list[$num_devices]=$ip
	let "num_devices++"
done < $ip_file

#folder org
mkdir -p logs
mkdir -p test-logs
mkdir -p visual 

# iterate on devices
for((i=1; i<num_devices; i++))
do 
	wifi_ip=${ip_list[$i]}
	if [ $opt == "reboot" ] 
	then 
		echo "Rebooting phone at $wifi_ip:8022"
		timeout $command_dur  ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo reboot" & 
		sleep 1 
	elif [ $opt == "wake" ] 
	then 
		echo "Waking phone at $wifi_ip:8022"
		ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo input keyevent KEYCODE_POWER" & 
		sleep 0.5
	elif [ $opt == "battery" ] 
	then 
		ans=`ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo dumpsys battery | grep \"level\""`
		echo -e "$i\t$wifi_ip\t$ans"
	elif [ $opt == "volume" ] 
	then 
		ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/termux/ && git pull && ./volume.sh" &
		sleep 0.5 
	elif [ $opt == "start" ] 
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
	elif [ $opt == "ps" ] 
	then
		#echo "Checking phone at $wifi_ip:8022"
		ans=`timeout $command_dur ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "ps aux | grep state-update | grep -v grep | wc -l"`
		echo -e "$wifi_ip\t$ans"
	elif [ $opt == "boot" ] 
	then 
		timeout $command_dur ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo pm list packages -f | grep com.argonremote.launchonboot" > /dev/null 2>&1
		res=$?
		msg="FAIL"
		if [ $res == 0 ] 
		then
			msg="SUCCESS"
		fi 
		echo -e "$i\t$wifi_ip\tBootApps:$msg"
	elif [ $opt == "selinux" ] 
	then 
		ans=`timeout $command_dur ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo setenforce 0 && sudo getenforce"`
		res=$?
		if [ $res != 0 ] 
		then
			msg="SSH-FAIL"
		else
			msg="SELINUX:"$ans
		fi 
		echo -e "$i\t$wifi_ip\t$msg"
	elif [ $opt == "cron" ]
	then 
		ans=`timeout $command_dur ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pidof crond" 2>/dev/null`
		ret_code=$? 
		if [ $ret_code -eq 0 -o $ret_code -eq 1 ] 
		then 
			if [ $ret_code -eq 0 ] 
			then 
				echo -e "$i\t$wifi_ip\tCRON-PID:$ans\t$ret_code"
			else
				echo -e "$i\t$wifi_ip\tNO-CRON-PID"
				#echo "attempting to enable cron for $wifi_ip..." 
				#ssh -oStrictHostKeyChecking=no -t -i $ssh_key -p 8022 $wifi_ip 'sh -c "sv-enable crond"' > /dev/null 2>1
				#sleep 3 
				#echo "checking again...."
				#ans=`timeout 5 ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pidof crond" 2>/dev/null`
				#ret_code=$?
				#if [ ! -z $ans ] 
				#then 
				#	echo -e "$i\t$wifi_ip\tCRON-PID-MANUAL:$ans\t$ret_code"
				#else 
				#	echo -e "$i\t$wifi_ip\tNO-CRON-MANUAL\t$ret_code"
				#fi 
			fi 
		else 
			if [ $ret_code -eq 255 ] 
			then 
				echo -e "$i\t$wifi_ip\tSSH-NO_ROUTE\t$ret_code"
			elif [ $ret_code -eq 124 ] 
			then 
				echo -e "$i\t$wifi_ip\tSSH-TIMEOUT\t$ret_code"
			else
				echo -e "$i\t$wifi_ip\tSSH-FAIL\t$ret_code"
			fi 
		fi 
	elif [ $opt == "test" ]
	then
		echo "Running a test at $wifi_ip:8022" #-- test-logs/log-$wifi_ip"
		ssh -T -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip 'sh -c "cd mobile-testbed/src/termux/ && ./state-update.sh test > logs/log-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &"'
		#sleep 1 
	elif [ $opt == "visual" ]
	then
		echo "Checking visual at $wifi_ip:8022 -- visual/log-$wifi_ip"
		ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/termux/ && ./check-visual.sh" > visual/log-$wifi_ip 2>&1 &
	elif [ $opt == "prep" ] 
	then
		echo "Prepping phone: $wifi_ip:8022"
		#echo "./check-update.sh $wifi_ip > logs/log-prepping-$wifi_ip 2>&1 &"
		./check-update.sh $wifi_ip > logs/log-prepping-$wifi_ip 2>&1 &
	else 
		echo "Command $opt not supported yet!"
	fi 
done
