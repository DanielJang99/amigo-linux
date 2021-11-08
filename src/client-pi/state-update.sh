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
    "pi_wifi": "${wifi}", 
    "usb_tethering":"${usbTethering}",
    "pi_free_space_GB":"${free_space}",
    "pi_cpu_util_perc":"${cpu_util}",
    "pi_mem_info":"${mem_info}", 
    "phone_foreground_app":"${foreground}",
    "phone_wifi_ip":"${wifi_ip}",
    "phone_wifi_ssid":"${phone_wifi_ssid}",
    "phone_mobile_ip":"${mobile_ip}"
    }
EOF
}

# generate simplified data to be POSTed to my server 
generate_post_data_simple(){
  cat <<EOF
    {
    "timestamp":"${curr_time}",
    "uid":"None",
    "pi_wifi": "${wifi}", 
    "pi_free_space_GB":"${free_space}",
    "pi_mem_info":"${mem_info}"
    }
EOF
}

# turn device off
turn_device_off(){
    adb -s $uid shell dumpsys window | grep "mAwake=false"
    if [ $? -eq 0 ]
    then
        myprint "Screen was OFF. Nothing to do"
    else
        sleep 2
        myprint "Screen is ON. Turning off"
        adb -s $uid shell "input keyevent KEYCODE_POWER"
    fi
}

# enable adb over wifi for phone under test 
enable_adb_wifi(){
	# logging 
	echo "Enabling adb over wifi"

	# open port on phone 
	max_attempt_time=60
	t1=`date +%s`
	t_p=0
	found="false"
	while [ $t_p -lt $max_attempt_time ] 
	do 
		adb devices | grep $wifi_ip:$def_port > /dev/null
		if [ $? -eq 0 ]
		then
			echo "Time passed: $t_p Device $wifi_ip:$def_port found"
			found="true"
			break
		else
			echo "Time passed: $t_p --> adb tcpip $def_port"
			adb tcpip $def_port
			sleep 2
			adb connect $wifi_ip:$def_port
		fi
		t2=`date +%s`
		let "t_p = t2 - t1"
	done
	
	# check if found or not 
	if [ $found == "false" ] 
	then 
		echo "ERROR: wifi could not be enabled"
		adb_wifi="false"
	fi 

	# all good 
	adb_wifi="true"
}

# parameters
curr_time=`date +%s`                 # current time 
MIN_INTERVAL=30                      # interval of status reporting (seconds)
package="com.example.sensorexample"  # our app 
def_port=5555                        # default ADB port (for ADB over wifi)
adb_wifi="false"                     # flag to keep track if we are running ADB over wifi or not
last_report_time="1635969639"        # last time a report was sent (init to an old time)
wifi="False"                         # keep track if pi is on wifi or not
freq=5                               # frequency in seconds for checking things to do 

# folder and file organization 
mkdir -p "./logs"
echo "testing" > ".last_command"
echo "testing" > ".last_command_pi"
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
	free_space=`df | grep "root" | awk '{print $4/(1000*1000)}'`
	mem_info=`free -m | grep "Mem" | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`

	# check for wifi 
	ifconfig | grep "wlan0" > /dev/null
	status=$?
	if [ $status -eq 0 ]
	then
		wifi="True"
	fi 

	# get id of phone connected
	num_devices=`adb devices | grep -v "List" | grep -v -e '^$' | wc -l`
	if [ $num_devices -gt 1 ] 
	then 
		adb_wifi="true"
		echo "Both USB and WiFi ADB are available. (common without human to remove USB cable when charging)!"
		#echo "Both USB and WiFi ADB are available. Something is not right. Relaying on WiFi"
		uid=`adb devices | grep -v "List" | grep -v -e '^$' | grep 192 | cut -f 1`
		#FIXME - notify user to disconnect cable? 
	elif [ $num_devices -eq 1 ]
	then
		uid=`adb devices | grep -v "List" | grep -v -e '^$' | cut -f 1`
		echo "ADB over USB available: $uid"
	elif [ $num_devices -eq 0 ]
	then 
		echo "No ADB identifier found :("
		# report simplified  data back to the server (when needed)
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
		else 
			echo "Short report to send: "
			echo "$(generate_post_data_simple)" 
			timeout 10 curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data_simple)" https://mobile.batterylab.dev:8082/status
			echo $current_time > ".last_report"
		fi
		continue
	fi 

	# understand WiFi and mobile phone connectivity
	wifi_ip="None"
	phone_wifi_ssid="None"
	adb -s $uid shell ifconfig wlan0 > ".wifi-info"
	if [ $? -eq 0 ] 
	then 
		wifi_ip=`cat ".wifi-info" | grep "inet addr" | cut -f 2 -d ":" | cut -f 1 -d " "`  #FIXME: is this constant across devices/locations? 
		# get WiFI SSID
		phone_wifi_ssid=`adb -s $uid shell dumpsys netstats | grep -E 'iface=wlan.*networkId' | head -n 1  | awk '{print $4}' | cut -f 2 -d "=" | sed s/","// | sed s/"\""//g`
	fi 
	mobile_ip="None"
	adb -s $uid shell ifconfig rmnet_data1 > ".mobile-info"
	if [ $? -eq 0 ] 
	then 
		mobile_ip=`cat ".mobile-info" | grep "inet addr" | cut -f 2 -d ":" | cut -f 1 -d " "`  #FIXME: is this constant across devices/locations? 
	fi 
	echo "Device info. Wifi: $wifi_ip Mobile: $mobile_ip"

	# make sure ADB identifier is updated 
	adb -s $uid shell "ls /storage/emulated/0/Android/data/com.example.sensorexample/files/" > /dev/null 2>&1
	if [ $? -ne 0 ]
	then 
		echo "App was never launched. Doing it now"
		adb -s $uid shell pm grant $package android.permission.ACCESS_FINE_LOCATION
		adb -s $uid shell pm grant $package android.permission.READ_PHONE_STATE
		#adb shell pm grant $package android.permission.READ_PRIVILEGED_PHONE_STATE #Q: is this even needed?
		adb -s $uid shell monkey -p $package 1
		sleep 3 
		adb -s $uid shell "input keyevent KEYCODE_HOME"	
	fi 
	adb -s $uid shell "ls /storage/emulated/0/Android/data/com.example.sensorexample/files/adb.txt" > /dev/null 2>&1
	if [ $? -ne 0 ] 
	then 
		# make sure no wifi UID is used 
		echo $uid  | grep "\." > /dev/null
		if [ $? -eq 1 ] 
		then 
			echo "Pushing ADB identifier to file..." 
			echo $uid  > "adb.txt"
			adb -s $uid push "adb.txt"  /storage/emulated/0/Android/data/com.example.sensorexample/files/
		else 
			echo "Skipping pushing ADB identifier since is WiFi one!"
		fi 
	fi 
	usb_adb_id=`cat adb.txt`

	# check if kenzo is in the foreground - if yes act accordingly 
	foreground=`adb -s $uid shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
	start_time=`date +%s`
	time_passed=0
	echo "Foreground app is: $foreground"
	while [ $foreground == "$package" -a $time_passed -lt 60 ] 
	do 
		current_time=`date +%s`
		ans=`timeout 10 curl -s https://mobile.batterylab.dev:8082/myaction?id=$usb_adb_id`
		if [ $? -ne 0 ] 
		then 
			echo "Issue with query to https://mobile.batterylab.dev:8082/myaction"
			sleep 5
			foreground=`adb -s $uid shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
			let "time_passed = current_time - start_time"
			continue
		fi 
		# check if command was found or not
		if [[ "$ans" == *"No command matching"* ]]
		then
			echo "No command found for this user"
		else 
			command=`echo $ans  | cut -f 1 -d ";"`
			comm_id=`echo $ans  | cut -f 3 -d ";"`
			# ad-hoc parsing for connect 
			if [[ "$command" == *"connect"* ]]
			then 
				ssid=`echo $command | cut -f 2 -d ","`
				password=`echo $command | cut -f 3 -d ","`
				command=`echo $command | cut -f 1 -d ","`
			fi 
			timestamp_ms=`echo $ans  | cut -f 2 -d ";"`
			timestamp=`echo $timestamp_ms | awk '{print int($1/1000)}'`
			
			# verify command was not just run
			last_comm_run=`cat ".last_command"`
			if [ $last_comm_run == $comm_id ] 
			then 
				echo "Command $command ($comm_id) not allowed since it matches last command run!!"
				continue
			fi 
			# verify is allowed command
			if [ $command == "recharge" -o $command == "tether" -o $command == "connect" ] 
			then 
				# verify command is recent 
				delta=`echo "$current_time $timestamp" | awk 'function abs(x){return ((x < 0.0) ? -x : x)} {print(abs($1 - $2))}'`
				if [ $delta -lt 60 ]  #FIXME 
				then 
					echo "Command $command is allowed!!" 
					echo $comm_id > ".last_command"
					if [ $command == "recharge" ] 
					then 
						# prompt user to disconnect the USB cable
						adb -s $uid shell am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es lock "Preparing-the-device-please-wait..."
						sleep 3 	

						# stop tethering if active 
						echo "Stop tethering (if active)"
						cd ../client-android/
						./activate-tethering.sh $uid stop
						cd - > /dev/null 
						sleep 5 

						# enable wifi over adb, if needed 
						echo "Enable ADB over wifi"
						enable_adb_wifi $uid
						
						# prompt user to disconnect the USB cable
						echo "Prompting use to disconnect USB cable..."
						adb -s $uid shell am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Please-disconnect-the-USB-cable"
					elif [ $command == "tether" ] 
					then 
						# verify that cable is connected
						first="true"
						time_passed=0
						while [ $num_devices -eq 1 -a $time_passed -gt 10 ] 
						do 
							#notify user to connect cable
							if [ $first == "true" ] 
							then 
								adb -s $uid shell am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Please-make-sure-the-USB-cable-is-connected!"
								echo "Notified user to connect the cable..."
								first="false"
							fi 
							sleep 5 
							current_time=`date +%s`
							num_devices=`adb devices | grep -v "List" | grep -v -e '^$' | wc -l`
							let "time_passed = current_time - start_time"
						done

						# disable ADB over wifi (if needed)
						adb disconnect $wifi_ip:$def_port > /dev/null 2>&1
						adb_wifi="false"

						# update adb id to usb identifier
						uid=$usb_adb_id
						
						# enable tethering over USB
						echo "Enable tethering (if active)"
						cd ../client-android/
						./activate-tethering.sh $uid start
						cd - > /dev/null 
						
						# return to app screen 
						adb -s $uid shell monkey -p $package 1
					elif [ $command == "connect" ] 
					then 
						echo "Connecting to $ssid using password $password"
						if [ ! -f "wpa_supplicant-draft.conf" ]
						then 
							echo "Something is wrong. Missing local file <<wpa_supplicant-draft.conf>>"
						else
							# rewrite loca wpa_supplicant file  
							echo "Deriving new  wpa_supplicant file..."
							cat wpa_supplicant-draft.conf | awk -v ssid="$ssid" -v psk="$password" '{if($1~/ssid/) print "\tssid=\""ssid"\""; else if($1~/psk/) print "\tpsk=\""psk"\""; else print $0}' > wpa_supplicant.conf
							cat wpa_supplicant.conf
							# restart wpa 
							echo "Applying change... (temp disabled)"
							#wpa_cli -i wlan0 reconfigure  # should be this one
						fi 
					fi 
					break 
				else 
					echo "Command is too old ($delta sec => $ans)"
				fi 
			fi 
		fi 

		# keep checking status
		sleep 1 
		foreground=`adb -s $uid shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
		let "time_passed = current_time - start_time"
	done
	if [ $time_passed -ge 60 ] 
	then 
		echo "Something wrong. Is user stuck in Kenzo app? Maybe forgot? Go HOME!"
		adb -s $uid shell "input keyevent KEYCODE_HOME"
	fi 

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
		
	# check for USB tethering
	usbTethering="False"
	ifconfig | grep "usb0" > /dev/null
	status=$?
	if [ $status -eq 0 ]
	then
		usbTethering="True"
	fi 

	# check CPU usage 
	prev_total=0
	prev_idle=0
	result=`cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	prev_idle=`echo "$result" | cut -f 2`
	prev_total=`echo "$result" | cut -f 3`
	sleep 2
	result=`cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`

	# send status update to the server
	echo "Report to send: "
	echo "$(generate_post_data)" 
	timeout 10 curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
	echo $current_time > ".last_report"

	# check if there is a new command to run for the pi 
	echo "Checking if there is a command to execute for the pi..."
	ans=`timeout 10 curl -s https://mobile.batterylab.dev:8082/piaction?id=$usb_adb_id`
	if [[ "$ans" == *"No command matching"* ]]
	then
		echo "No command found for this pi"
	else 
		command_pi=`echo $ans  | cut -f 1 -d ";"`
		comm_id_pi=`echo $ans  | cut -f 3 -d ";"`
	
		# verify command was not just run
		last_pi_comm_run=`cat ".last_command_pi"`
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
