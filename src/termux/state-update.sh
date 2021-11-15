#!/bin/bash
## NOTE: report updates to the central server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "timestamp":"${curr_time}",
    "uid":"${uid}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}", 
    "battery_level":"${phone_battery}",
    "location_info":"${loc_str}",
    "foreground_app":"${foreground}",
    "wifi_iface":"$wifi_iface", 
    "wifi_ip":"${wifi_ip}",
    "wifi_ssid":"${wifi_ssid}",
    "wifi_info":"${wifi_info}",
    "wifi_qual":"${wifi_qual}",
    "net_testing_proc":"${num}", 
    "mobile_iface":"$mobile_iface",
    "mobile_ip":"${mobile_ip}",
    "mobile_state":"${mobile_state}", 
    "mobile_signal":"${mobile_signal}"
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

# compute current CPU usage 
check_cpu(){
	prev_total=0
	prev_idle=0
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	prev_idle=`echo "$result" | cut -f 2`
	prev_total=`echo "$result" | cut -f 3`
	sleep 2
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`
}

# parameters
curr_time=`date +%s`                   # current time 
freq=10                                # interval for checking things to do 
REPORT_INTERVAL=60                     # interval of status reporting (seconds)
NET_INTERVAL=300                       # interval of networking testing 
package="com.example.sensorexample"    # our app 
last_report_time="1635969639"          # last time a report was sent (init to an old time)
last_net="1635969639"                  # last time a net test was done (init to an old time) 
asked_to_charge="false"                # keep track if we already asked user to charge their phone

# retrieve unique ID for this device 
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`

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

# make sure SELinux is permissive
ans=`sudo getenforce`
myprint "SELinux: $ans"
if [ $ans == "Enforcing" ]
then
    myprint "Disabling SELinux"
    sudo setenforce 0
    sudo getenforce
fi

# make sure location setting is correct 
# TODO


# external loop 
to_run=`cat ".status"`
myprint "Script will run with a $freq sec frequency. To stop: <<echo \"false\" > \".status\""
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
	current_time=`date +%s`
	suffix=`date +%d-%m-%Y`
	
	# check simple stats
	free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
	mem_info=`free -m | grep "Mem" | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`

	# get phone battery level
	phone_battery=`sudo dumpsys battery | grep "level"  | cut -f 2 -d ":"`
	charging=`sudo dumpsys battery | grep "AC powered"  | cut -f 2 -d ":"`
	if [ $phone_battery -lt 20 -a $charging == "false" -a $asked_to_charge == "false" ] 
	then 
		myprint "Prompting user to charge their phone..." #FIXME 
		am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Phone-battery-is-low.-Consider-charging!"
		asked_to_charge="true"
	else 
		asked_to_charge="false"
	fi 
	
	# understand WiFi and mobile phone connectivity
	#wifi_iface=`ifconfig | grep "wlan" | cut -f 1 -d ":"`
	#mobile_iface=`ifconfig | grep "data" | cut -f 1 -d ":"`
	sudo dumpsys netstats > .data
	wifi_iface=`cat .data | grep "WIFI" | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
	mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
	myprint "Discover wifi ($wifi_iface) and mobile ($mobile_iface)"
	wifi_ip="None"
	phone_wifi_ssid="None"
	wifi_ip=`ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}'` 
	if [ $? -eq 0 ] 
	then 
		# get WiFI SSID
		wifi_ssid=`sudo dumpsys netstats | grep -E 'iface=wlan.*networkId' | head -n 1  | awk '{print $4}' | cut -f 2 -d "=" | sed s/","// | sed s/"\""//g`
		# get more info
		sudo dumpsys wifi > ".wifi"
		wifi_info=`cat ".wifi" | grep "mWifiInfo"`
		wifi_qual=`cat ".wifi" | grep "mLastSignalLevel"`
		# mWifiInfo
		#mLastSignalLevel
	else
		wifi_ip="none"
		wifi_ssid="none"
		wifi_info="none"
		wifi_qual="none"
	fi 
	mobile_ip=`ifconfig $mobile_iface | grep "\." | grep -v packets | awk '{print $2}'`
	if [ $? -eq 0 ] 
	then
		# get mobile network info 
		sudo dumpsys telephony.registry > tel
		mobile_state=`cat tel | grep "mServiceState" | head -n 1`
		mobile_signal=`cat tel | grep "mSignalStrength" | head -n 1`
	else 
		mobile_state="none"
		mobile_ip="none"
		mobile_signal="none"
	fi 
	myprint "Device info. Wifi: $wifi_ip Mobile: $mobile_ip"

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

	# current app in the foreground
	foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`

	# check if it is time to run net experimets 
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | wc -l`
	if [ -f ".last_net" ] 
	then 
		last_net=`cat ".last_net"`
	fi 
	let "time_from_last_net = current_time - last_net"
	myprint "Time from last net: $time_from_last_net sec"
	if [ $time_from_last_net -gt $NET_INTERVAL ] 
	then 
		if [ $num -eq 0 ] 
		then 
			(./net-testing.sh $suffix $current_time &)
			echo $current_time > ".last_net"
		else 
			myprint "Postponing net-testing since still running (numProc: $num)"
		fi 
	fi 

	# check if it is time to status report
	if [ -f ".last_report" ] 
	then 
		last_report_time=`cat ".last_report"`
	fi 
	let "time_from_last_report = current_time - last_report_time"
	myprint "Time from last report: $time_from_last_report sec"
	if [ $time_from_last_report -gt $REPORT_INTERVAL ] 
	then 
		# dump location information (only start googlemaps if not net-testing to avoid collusion)
		res_dir="locationlogs/${suffix}"
		mkdir -p $res_dir
		if [ $num -eq 0 ] 
		then 
			# check CPU usage (background)
			check_cpu &

			myprint "Launching googlemaps to improve location accuracy"
			sudo monkey -p com.google.android.apps.maps 1 > /dev/null 2>&1
			sleep 5
			myprint "Verify it is enough to obtain fresh location information..."
			#sudo input tap 630 550  # this GUI part might be moving...	
			#sudo input tap 340 100 # searching then also require cleaning
			#sudo input text "here"	
			#sleep 2 
			#sudo input keyevent 66
			sudo input keyevent KEYCODE_HOME
		else 
			myprint "Skipping maps launch since net-testing is running"
			# check CPU usage  (foreground)
			check_cpu &
		fi 
		sudo dumpsys location | grep "hAcc" > $res_dir"/loc-$current_time.txt"
		loc_str=`cat  $res_dir"/loc-$current_time.txt" | grep passive | head -n 1`

		# send status update to the server
		myprint "Report to send: "
		echo "$(generate_post_data)" 
		timeout 10 curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
		echo $current_time > ".last_report"
	fi 
	
	# check if there is a new command to run
	myprint "Checking if there is a command to execute (consider lowering/increasing frequency)..."
	ans=`timeout 10 curl -s https://mobile.batterylab.dev:8082/piaction?id=$uid`
	if [[ "$ans" == *"No command matching"* ]]
	then
		myprint "No command found"
	else 
		command_pi=`echo $ans  | cut -f 1 -d ";"`
		comm_id_pi=`echo $ans  | cut -f 3 -d ";"`
	
		# verify command was not just run
		last_pi_comm_run=`cat ".last_command_pi"`
		#echo "==> $last_pi_comm_run -- $comm_id_pi"
		if [ $last_pi_comm_run == $comm_id_pi ] 
		then 
			myprint "Command $command_pi ($comm_id_pi) not allowed since it matches last command run!!"
		else 
			eval $command_pi & 
			ans=`timeout 10 curl -s https://mobile.batterylab.dev:8082/commandDone?id=$uid\&command_id=$comm_id_pi`
			myprint "Informed server that command is being executed. ANS: $ans"
		fi 
		echo $comm_id_pi > ".last_command_pi"
		# FIXME: decide if to spawn from here, stop, etc. 
		# FIXME: need a duration and some battery logic? Can be done at server too!
	fi 
done
