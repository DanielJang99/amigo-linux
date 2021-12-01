#!/data/data/com.termux/files/usr/bin/env bash
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

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}", 
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "uptime":"${uptime_info}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}", 
    "battery_level":"${phone_battery}",
    "location_info":"${loc_str}",
    "foreground_app":"${foreground}",
    "net_testing_proc":"${num}", 
    "wifi_iface":"${wifi_iface}", 
    "wifi_ip":"${wifi_ip}",
    "wifi_ssid":"${wifi_ssid}",
    "wifi_info":"${wifi_info}",
    "wifi_qual":"${wifi_qual}",
    "today_wifi_data":"${wifi_data}",
    "mobile_iface":"${mobile_iface}",
    "mobile_ip":"${mobile_ip}",
    "mobile_state":"${mobile_state}", 
    "mobile_signal":"${mobile_signal}",
    "today_mobile_data":"${mobile_data}"
    }
EOF
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
freq=10                                # interval for checking things to do 
REPORT_INTERVAL=180                    # interval of status reporting (seconds)
NET_INTERVAL=600                       # interval of networking testing 
package="com.example.sensorexample"    # our app 
last_report_time="1635969639"          # last time a report was sent (init to an old time)
last_net="1635969639"                  # last time a net test was done (init to an old time) 
asked_to_charge="false"                # keep track if we already asked user to charge their phone
prev_wifi_traffic=0                    # keep track of wifi traffic used today
prev_mobile_traffic=0                  # keep track of mobile traffic used today
MAX_MOBILE_GB=3                        # maximum mobile data usage per day
testing="false"                        # keep track if we are testing or not 

# check if testing
if [ $# -eq 1 ] 
then 
	testing="true"
fi 

# retrieve unique ID for this device 
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`

# derive B from GB
let "MAX_MOBILE = MAX_MOBILE_GB * 1000000000"

# folder and file organization 
mkdir -p "./logs"
mkdir -p "./data/wifi"
mkdir -p "./data/mobile"
if [ ! -f ".last_command" ] 
then 
	echo "testing" > ".last_command"
fi 
if [ ! -f ".last_command_pi" ]
then
	echo "testing" > ".last_command_pi"
fi 
echo "true" > ".status"
if [ ! -f ".net_status" ] 
then
	echo "false" > ".net_status"
fi 

# make sure SELinux is permissive
ans=`sudo getenforce`
myprint "SELinux: $ans"
if [ $ans == "Enforcing" ]
then
    myprint "Disabling SELinux"
    sudo setenforce 0
    sudo getenforce
fi

# find termuxt user 
termux_user=`whoami`

# make sure location setting is correct 
# TODO

# external loop 
to_run=`cat ".status"`
myprint "Script will run with a $freq sec frequency. To stop: <<echo \"false\" > \".status\""
last_loop_time=0
while [ $to_run == "true" ] 
do 
	# keep track of time
	current_time=`date +%s`
	suffix=`date +%d-%m-%Y`

	# check if user wants us to pause 
	user_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/running.txt"
	user_status="true"
	if [ -f $user_file ] 
	then 
		user_status=`sudo cat $user_file`
	fi 
	if [ $user_status == "false" ] 
	then 
		echo "User is asking to stop!"
		echo "false" > ".status"
		./stop-net-testing.sh #FIXME
		echo "FIXME: need to potentially stop more stuff"
		break 
	fi 

	# check if user wants to run a test 
	sel_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/selection.txt"
	if [ -f $sel_file ] 
	then 
		sel_id=`sudo cat $sel_file | cut -f 1`
		time_sel=`sudo cat $sel_file | cut -f 2`
		let "time_from_sel = current_time - time_sel"
		let "time_check = freq + freq/2"
		echo "TEMP: User entered selection: $sel_id (Time: $time_sel -- $current_time)" #{"OPEN A WEBPAGE", "WATCH A VIDEO", "JOIN A VIDEOCONFERENCE"};
		if [ $time_from_sel -lt $time_check ] 
		then 
			echo "User entered selection: $sel_id (Time: $time_sel -- $current_time)" #{"OPEN A WEBPAGE", "WATCH A VIDEO", "JOIN A VIDEOCONFERENCE"};
			case $sel_id in
  				"0")
					./stop-net-testing.sh #FIXME
					echo "Open a webpage -- FIXME (just one URL)"
					./web-test.sh  --suffix $suffix --id $t_s --iface $iface --single
				    ;;

  				"1")
					echo "Watch a video -- ./youtube-test.sh --suffix $suffix --id $current_time-"user" --iface $def_iface"
					./stop-net-testing.sh #FIXME
					./youtube-test.sh --suffix $suffix --id $current_time-"user" --iface $def_iface
				    ;;
				  *)
					echo "Option not supported"
					;;
			esac
		fi 
	fi 

	# loop rate control 
	let "t_p = freq - (current_time - last_loop_time)"
	if [ $t_p -gt 0 ] 
	then 
		sleep $t_p
	fi 
	last_loop_time=$current_time
	to_run=`cat ".status"`
	current_time=`date +%s`

	# get update on data sent/received
	wifi_today_file="./data/wifi/"$suffix".txt"
	mobile_today_file="./data/mobile/"$suffix".txt"
	wifi_data=0
	mobile_data=0
	if [ -f $wifi_today_file ] 
	then 
		wifi_data=`cat $wifi_today_file`
	fi 
	if [ -f $mobile_today_file ] 
	then 
		mobile_data=`cat $mobile_today_file`
	fi 

	# understand WiFi and mobile phone connectivity
	sudo dumpsys netstats > .data
	wifi_iface=`cat .data | grep "WIFI" | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
	mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
	myprint "Discover wifi ($wifi_iface) and mobile ($mobile_iface)"
	wifi_ip="None"
	phone_wifi_ssid="None"

	# get more wifi info if active 
	def_iface="none"
	if [ ! -z $wifi_iface ]
	then 
		wifi_ip=`ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}'` 
		wifi_ssid=`sudo dumpsys netstats | grep -E 'iface=wlan.*networkId' | head -n 1  | awk '{print $4}' | cut -f 2 -d "=" | sed s/","// | sed s/"\""//g`
		sudo dumpsys wifi > ".wifi"
		wifi_info=`cat ".wifi" | grep "mWifiInfo"`
		wifi_qual=`cat ".wifi" | grep "mLastSignalLevel"`
		wifi_traffic=`ifconfig $wifi_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
		def_iface=$wifi_iface
	
		# update data consumed 
		if [ $prev_wifi_traffic != 0 ] 
		then 
			let "wifi_data += (wifi_traffic - prev_wifi_traffic)"
			echo $wifi_data > $wifi_today_file
		fi 
		prev_wifi_traffic=$wifi_traffic
	else
		wifi_ip="none"
		wifi_ssid="none"
		wifi_info="none"
		wifi_qual="none"
		wifi_traffic="none"
	fi 
	
	# get more mobile info if active 
	if [ ! -z $mobile_iface ]
	then
		mobile_ip=`ifconfig $mobile_iface | grep "\." | grep -v packets | awk '{print $2}'`
		sudo dumpsys telephony.registry > ".tel"
		mobile_state=`cat ".tel" | grep "mServiceState" | head -n 1`
		mobile_signal=`cat ".tel" | grep "mSignalStrength" | head -n 1`
		mobile_traffic=`ifconfig $mobile_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
		if [ $def_iface == "none" ] 
		then
			def_iface=$mobile_iface
		fi 
		if [ $prev_mobile_traffic != 0 ] 
		then 
			let "mobile_data += (mobile_traffic - prev_mobile_traffic)"
			echo $mobile_data > $mobile_today_file
		fi 
		prev_mobile_traffic=$mobile_traffic
	else 
		mobile_state="none"
		mobile_ip="none"
		mobile_signal="none"
		mobile_traffic="none"
	fi 
	myprint "Device info. Wifi: $wifi_ip Mobile: $mobile_ip DefaultIface: $def_iface"

	# check simple stats
	free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
	mem_info=`free -m | grep "Mem" | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`

	# get phone battery level
	phone_battery=`sudo dumpsys battery | grep "level"  | cut -f 2 -d ":"`
	charging=`sudo dumpsys battery | grep "AC powered"  | cut -f 2 -d ":"`
	if [ $phone_battery -lt 20 -a $charging == "false" ] 
	then 
 		if [ $asked_to_charge == "false" ] 
		then 
			myprint "Phone battery is low. Asking to recharge!"
			termux-notification -c "Please charge your phone!" -t "recharge" --icon warning --prio high --vibrate pattern 500,500
			am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Phone-battery-is-low.-Consider-charging!"
			asked_to_charge="true"
		fi 
	else 
		asked_to_charge="false"
	fi 
	
	# current app in the foreground
	foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`

	# check if it is time to run net experimets 
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | wc -l`
	if [ -f ".last_net" ] 
	then 
		last_net=`cat ".last_net"`
	fi 
	net_status=`cat ".net_status"`
	let "time_from_last_net = current_time - last_net"
	myprint "Time from last net: $time_from_last_net sec ShouldRun: $net_status"
	if [ $time_from_last_net -gt $NET_INTERVAL -a $net_status == "true" ] # if it is time and we should run
	then 
		if [ $num -eq 0 ]                       # if previous test is not still running 
		then 	
			if [ $def_iface != "none" ]         # if a connectivity is found
			then
				if [ $def_iface == $mobile_iface -a $mobile_data -gt $MAX_MOBILE ]      # if enough mobile data is available 
				then 
					myprint "Skipping net-testing since we are on mobile and data limit passed ($mobile_data -> $MAX_MOBILE)"
				else 
					(./net-testing.sh $suffix $current_time $iface >  logs/net-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &)
					num=1
					echo $current_time > ".last_net"
				fi 
			else 
				myprint "Skipping net-testing since no connection was found" 
			fi 
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
		# check CPU usage (background)
		check_cpu

		# dump location information (only start googlemaps if not net-testing to avoid collusion)
		res_dir="locationlogs/${suffix}"
		mkdir -p $res_dir
		if [ ! -f ".locked" ] 
		then 
			turn_device_on
			myprint "Launching googlemaps to improve location accuracy"
			sudo monkey -p com.google.android.apps.maps 1 > /dev/null 2>&1
			sleep 10
			sudo input keyevent KEYCODE_HOME
			turn_device_off
		fi 
		sudo dumpsys location | grep "hAcc" > $res_dir"/loc-$current_time.txt"
		loc_str=`cat $res_dir"/loc-$current_time.txt" | grep passive | head -n 1`

		# get uptime
		uptime_info=`uptime`

		# send status update to the server
		myprint "Report to send: "
		echo "$(generate_post_data)" 
	
		if [ $def_iface == "none" ] 
		then
			myprint "Skipping report sending since not connected"
		else 
			timeout 10 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
		fi 
		echo $current_time > ".last_report"
	fi 
	
	# check if there is a new command to run
	if [ $def_iface != "none" ] 
	then	
		prev_command="none"
		if [ -f ".prev_command" ] 
		then
			prev_command=`cat ".prev_command"`
		fi 
		myprint "Checking if there is a command to execute (consider lowering/increasing frequency)..."
		ans=`timeout 10 curl -s "https://mobile.batterylab.dev:8082/action?id=${uid}&prev_command=${prev_command}&termuxUser=${termux_user}"`
		if [[ "$ans" == *"No command matching"* ]]
		then
			myprint "No command found"
		else 	
			command=`echo $ans  | cut -f 1 -d ";"`
			comm_id=`echo $ans  | cut -f 3 -d ";"`
			duration=`echo $ans  | cut -f 4 -d ";"`	
			background=`echo $ans  | cut -f 5 -d ";"`
			myprint "Command:$command- ID:$comm_id - MaxDuration:$duration - IsBackground:$background - PrevCommand:$prev_command"

			# verify command was not just run
			if [ $prev_command == $comm_id ] 
			then 
				myprint "Command not allowed since it matches last command run!!"
			else 
				if [ $background == "true" ] 
				then 
					eval timeout $duration $command & 
					comm_status=$?
					myprint "Command started in background. Status: $comm_status"
				else 
					eval timeout $duration $command
					comm_status=$?
					myprint "Command executed. Status: $comm_status"
				fi
				ans=`timeout 10 curl -s "https://mobile.batterylab.dev:8082/commandDone?id=${uid}&command_id=${comm_id}&status=${comm_status}&termuxUser=${termux_user}"`
				myprint "Informed server about last command run. ANS: $ans"
			fi 
			echo $comm_id > ".prev_command"
		fi 
	fi 

	# stop here if testing 
	if [ $testing == "true" ] 
	then
		myprint "One simple test was requested, interrupting!" 
		break
	fi 
done

# logging 
myprint "A request to interrupt $0 was received and executed. All good!"
