#!/bin/bash
## NOTE: report updates to the central server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "timestamp":"${curr_time}",
    "uid":"${uid}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}", 
    "foreground_app":"${foreground}",
    "wifi_ip":"${wifi_ip}",
    "wifi_ssid":"${phone_wifi_ssid}",
    "mobile_ip":"${mobile_ip}",
    "battery_level":"${phone_battery}"
    }
EOF
}

# turn device off
turn_device_off(){
    sudo dumpsys window | grep "mAwake=false"
    if [ $? -eq 0 ]
    then
        myprint "Screen was OFF. Nothing to do"
    else
        sleep 2
        myprint "Screen is ON. Turning off"
        sudo input keyevent KEYCODE_POWER
    fi
}

# parameters
curr_time=`date +%s`                 # current time 
MIN_INTERVAL=30                      # interval of status reporting (seconds)
package="com.example.sensorexample"  # our app 
last_report_time="1635969639"        # last time a report was sent (init to an old time)
freq=5                               # frequency in seconds for checking things to do 
asked_to_charge="false"              # keep track if we already asked user to charge their phone

# generate a unique id first time is run
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g`

# folder and file organization 
mkdir -p "./logs"
if [ ! -f ".last_command" ] 
then 
	echo "testing" > ".last_command"
fi 
if [ ! -f ".last_command_pi" ] 
then 
	echo "testing" > ".last_command_pi"
fi 
echo "true" > ".status"

# external loop 
to_run=`cat ".status"`
echo "Script will run with a 5 sec frequency. To stop: <<echo \"false\" > \".status\""
last_loop_time=0
while [ $to_run == "true" ] 
do 
	# loop rate control 
	current_time=`date +%s`
	let "t_p = freq - (current_time - last_loop_time)"
	if [ $t_p -gt 0 ] 
	then 
		sleep $t_p
	fi 
	last_loop_time=$current_time
	to_run=`cat ".status"`

	# check simple stats from the pi
	free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
	mem_info=`free -m | grep "Mem" | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`

	# get phone battery level
	phone_battery=`sudo dumpsys battery | grep "level"  | cut -f 2 -d ":" | xargs`
	charging=`sudo dumpsys battery | grep "AC powered"  | cut -f 2 -d ":"`
	if [ $phone_battery -lt 20 -a $charging == "false" -a $asked_to_charge == "false" ] 
	then 
		echo "Prompting user to charge their phone..." #FIXME 
		am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Phone-battery-is-low.-Consider-charging!"
		asked_to_charge="true"
	else 
		asked_to_charge="false"
	fi 

	# understand WiFi and mobile phone connectivity
	wifi_ip="None"
	phone_wifi_ssid="None"
	ifconfig wlan0 > ".wifi-info"
	if [ $? -eq 0 ] 
	then 
		wifi_ip=`cat ".wifi-info" | grep "\." | grep -v packets | awk '{print $2}'`
		# get WiFI SSID
		phone_wifi_ssid=`sudo dumpsys netstats | grep -E 'iface=wlan.*networkId' | head -n 1  | awk '{print $4}' | cut -f 2 -d "=" | sed s/","// | sed s/"\""//g`
	fi 
	mobile_ip="None"
	sudo ifconfig rmnet_data1 > ".mobile-info"
	if [ $? -eq 0 ] 
	then 
		mobile_ip=`cat ".mobile-info" | grep "\." | grep -v packets | awk '{print $2}'`
	fi 
	echo "Device info. Wifi: $wifi_ip Mobile: $mobile_ip"

	# make sure device identifier is updated in the app  -- do we even need an app? 
	#ls "/storage/emulated/0/Android/data/com.example.sensorexample/files/" > /dev/null 2>&1
	#if [ $? -ne 0 ]
	#then 
	#	echo "App was never launched. Doing it now"
	#	pm grant $package android.permission.ACCESS_FINE_LOCATION
	#	pm grant $package android.permission.READ_PHONE_STATE
	#	sudo monkey -p $package 1
	#	sleep 3 
	#	sudo input keyevent KEYCODE_HOME
	#fi 
	#ls "/storage/emulated/0/Android/data/com.example.sensorexample/files/adb.txt" > /dev/null 2>&1
	#if [ $? -ne 0 ] 
	#then 
	#	echo "Pushing ADB identifier to file..." 
	#	echo $uid  > "/storage/emulated/0/Android/data/com.example.sensorexample/files/adb.txt"
	#fi 

	# if not time to report, go back up 
	if [ -f ".last_report" ] 
	then 
		last_report_time=`cat ".last_report"`
	fi 
	current_time=`date +%s`
	let "time_from_last_report = current_time - last_report_time"
	echo "Time from last report: $time_from_last_report sec"
	if [ $time_from_last_report -lt $MIN_INTERVAL ] 
	then 
		echo "Not time to report status"
		continue
	fi 
		
	# check CPU usage 
	prev_total=0
	prev_idle=0
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	prev_idle=`echo "$result" | cut -f 2`
	prev_total=`echo "$result" | cut -f 3`
	sleep 2
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`

	# send status update to the server
	echo "Report to send: "
	echo "$(generate_post_data)" 
	timeout 10 curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
	echo $current_time > ".last_report"

	# check if there is a new command to run
	echo "Checking if there is a command to execute for the pi..."
	ans=`timeout 10 curl -s https://mobile.batterylab.dev:8082/piaction?id=$usb_adb_id`
	if [[ "$ans" == *"No command matching"* ]]
	then
		echo "No command found"
	else 
		command_pi=`echo $ans  | cut -f 1 -d ";"`
		comm_id_pi=`echo $ans  | cut -f 3 -d ";"`
	
		# verify command was not just run
		last_pi_comm_run=`cat ".last_command_pi"`
		echo "==> $last_pi_comm_run -- $comm_id_pi"
		if [ $last_pi_comm_run == $comm_id_pi ] 
		then 
			echo "Command $command_pi ($comm_id_pi) not allowed since it matches last command run!!"
		else 
			eval $command_pi
		fi 
		echo $comm_id_pi > ".last_command_pi"
		# FIXME: decide if to spawn from here, stop, etc. 
		# FIXME: need a duration and some battery logic? Can be done at server too!
	fi
done
