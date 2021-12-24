#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: report updates to the central server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	echo "false" > ".cpu_monitor"
	echo "false" > ".status"
	sudo cp ".status" "/storage/emulated/0/Android/data/com.example.sensorexample/files/status.txt"	
	echo "false" > ".cpu_monitor"
	./stop-net-testing.sh
	clean_file ".locked"
	close_all
	turn_device_off
	exit -1 
}

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

# check account verification via YT
check_account_via_YT(){
	# make sure screen is on 
	turn_device_on

	# launch youtube
	myprint "Launching YT and allow to settle..."
	sudo monkey -p com.google.android.youtube 1 > /dev/null 2>&1 

	# lower all the volumes
	myprint "Making sure volume is off"
	sudo media volume --stream 3 --set 0    # media volume
	sudo media volume --stream 1 --set 0	# ring volume
	sudo media volume --stream 4 --set 0	# alarm volume

	# wait for YT 
	youtube_error="false"
	sleep 5 
	myprint "Waiting for YT to load (aka detect \"WatchWhileActivity\")"
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
	c=0
	while [ $curr_activity != "WatchWhileActivity" ] 
	do 
		sleep 3 
		curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
		let "c++"
		if [ $c -ge 10 ]
		then 
			myprint "Something went wrong loading YouTube"
			youtube_error="true"
			break
		fi 
	done

	# click account notification if there (guessing so far)
	if [ $youtube_error == "false" ]
	then
		sleep 3
		sudo input tap 560 725
		sleep 10
		sudo dumpsys window windows | grep -E 'mCurrentFocus' | grep "MinuteMaidActivity"
		need_to_verify=$?
		if [ $need_to_verify -eq 0 ]
		then
		    myprint "Google account validation needed"
		    sleep 10 
		    sudo input tap 600 1200
		    sleep 5
		    sudo input text "Bremen2013"
		    sleep 3
		    sudo input keyevent KEYCODE_ENTER
		    sleep 10
		    sudo dumpsys window windows | grep -E 'mCurrentFocus' | grep MinuteMaidActivity
		    if [ $? -eq 0 ]
		    then
		        myprint "ERROR - notification cannot be accepted. Inform USER"
		        echo "not-authorized" > ".google_status"
		    	safe_stop
		    else
		    	echo "authorized" > ".google_status"
		        myprint "Google account is now verified"
		    fi
		else
			echo "authorized" > ".google_status"
		    myprint "Google account is already verified"
		fi
	fi 

	# make sure screen is off and nothing running
	close_all 
	turn_device_off
}

# generate data to be POSTed to my server
generate_post_data_short(){
  cat <<EOF
    {
    "vrs_num":"${vrs}",      
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "msg":"${msg}"
    }
EOF
}

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "vrs_num":"${vrs}",  
    "today":"${suffix}", 
    "timestamp":"${current_time}",
    "server_port":"${SERVER_PORT}",
    "last_curl_dur:"${curl_duration},
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "googleStatus":"${google_status}",
    "timeGoogleCheck":"${t_last_google}",
    "uptime":"${uptime_info}",
    "isPaused":"${isPaused}",
    "num_kenzo":"${N_kenzo}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}", 
    "battery_level":"${phone_battery}",
    "charging":"${charging}",
    "location_info":"${loc_str}",
    "gps_loc":"${gps_loc}",
    "network_loc":"${network_loc}",
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
	myprint "Start monitoring CPU (PID: $$)"
	echo "true" > ".cpu_monitor"
	to_monitor=`cat ".cpu_monitor"`
	to_monitor="true"
	prev_total=0
	prev_idle=0
	while [ $to_monitor == "true" ]
	do 
		result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
		prev_idle=`echo "$result" | cut -f 2`
		prev_total=`echo "$result" | cut -f 3`
		sleep 2
		result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
		echo "$result" | cut -f 1 | cut -f 1 -d "%" > ".cpu-usage"
		sleep 2 
		to_monitor=`cat ".cpu_monitor"`
	done
}

# update location information 
update_location(){
	res_dir="locationlogs/${suffix}"
	mkdir -p $res_dir		
	timeout $MAX_LOCATION termux-location -p network -r last > $res_dir"/network-loc-$current_time.txt"
	lat=`cat $res_dir"/network-loc-$current_time.txt" | grep "latitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`		
	long=`cat $res_dir"/network-loc-$current_time.txt" | grep "longitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`
	network_loc="$lat,$long"
	timeout $MAX_LOCATION termux-location -p gps -r last > $res_dir"/gps-loc-$current_time.txt"		
	lat=`cat $res_dir"/gps-loc-$current_time.txt" | grep "latitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`		
	long=`cat $res_dir"/gps-loc-$current_time.txt" | grep "longitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`
	gps_loc="$lat,$long"		
	sudo dumpsys location > $res_dir"/loc-$current_time.txt"
	loc_str=`cat $res_dir"/loc-$current_time.txt" | grep "hAcc" | grep "passive" | head -n 1`
	gzip $res_dir"/loc-$current_time.txt"
}

# helper to maintain up-to-date wifi/mobile info 
update_wifi_mobile(){
	sudo dumpsys netstats > .data
	wifi_iface=`cat .data | grep "WIFI" | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
	#mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
	mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | grep "rmnet" | grep "true" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
	def_iface="none"
	if [ ! -z $wifi_iface ]
	then 
		def_iface=$wifi_iface
	else  
		if [ ! -z $mobile_iface ]
		then
			def_iface=$mobile_iface
	 	fi 
	fi 
		
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
	myprint "Discover wifi ($wifi_iface) and mobile ($mobile_iface)"
	wifi_ip="None"
	phone_wifi_ssid="None"

	# resume current wifi counter for this wifi 
	if [ -f ".force_counter" ]
	then 
		force_net_test=`cat ".force_counter"`
	else 
		force_net_test=0
		echo $force_net_test > ".force_counter"
	fi

	# get more wifi info if active 
	if [ ! -z $wifi_iface ]
	then 
		wifi_ip=`ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}'` 
		wifi_ssid=`sudo dumpsys netstats | grep -E 'iface=wlan.*networkId' | head -n 1  | awk '{print $4}' | cut -f 2 -d "=" | sed s/","// | sed s/"\""//g`
		sudo dumpsys wifi > ".wifi"
		wifi_info=`cat ".wifi" | grep "mWifiInfo"`
		wifi_qual=`cat ".wifi" | grep "mLastSignalLevel"`
		wifi_traffic=`ifconfig $wifi_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
	
		# update data consumed 
		if [ $prev_wifi_traffic != 0 ] 
		then 
			let "wifi_data += (wifi_traffic - prev_wifi_traffic)"
			echo $wifi_data > $wifi_today_file
		fi 
		prev_wifi_traffic=$wifi_traffic

		# keep track of wifi encountered 
		wifi_list="wifi-info/ssid-list"
		mkdir -p "wifi-info"		 
		if [ -f $wifi_list ]
		then
			cat $wifi_list | grep "$wifi_ssid" > /dev/null
			if [ $? -ne 0 ]
			then 
				myprint "Found a new wifi: $wifi_ssid"
				force_net_test=6
				echo $wifi_ssid >> $wifi_list			
			fi 
			echo $force_net_test > ".force_counter"				
		else 
			echo $wifi_ssid > $wifi_list
			force_net_test=6
			echo $force_net_test > ".force_counter"				
		fi 	
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
	if [ -f ".cpu-usage" ] 
	then 
		cpu_util=`cat ".cpu-usage" | cut -f 1 -d "."`
	fi 
	myprint "Device info. Wifi:$wifi_ip Mobile:$mobile_ip DefaultIface:$def_iface GoogleAccountStatus:$google_status CPULast:$cpu_util IsPaused:$isPaused NetTesting:$num"

}

# parameters
slow_freq=30                           # interval for checking commands to run (slower)
fast_freq=5                            # interval for checking the app (faster)
#SERVER_PORT=8082                      # port of our web app
SERVER_PORT=8083                       # web app port (when debugging at server)
REPORT_INTERVAL=300                    # interval of status reporting (seconds)
NET_INTERVAL=5400                      # interval of networking testing 
NET_INTERVAL_SHORT=2700                # short interval of net testing (just on mobile)
NET_INTERVAL_FORCED=1800               # short interval of net testing (wifi, hopefully on planes)
GOOGLE_CHECK_FREQ=10800                # interval of Google account check via YT (seconds)
WIFI_GMAPS=1800                        # lower frequency of launchign GMAPS when on wifi 				
MAX_ZEUS_RUNS=6                        # maximum number of zeus per day 
MAX_PAUSE=1800                         # maximum time a user can pause (600) 
MAX_LOCATION=5                         # timeout of termux-location command
kenzo_pkg="com.example.sensorexample"  # our app package name 
last_report_time=0                     # last time a report was sent 
last_net=0                             # last time a net test was done  
t_wifi_mobile_update=0                 # last time wifi/mobile info was checked 
asked_to_charge="false"                # keep track if we already asked user to charge their phone
prev_wifi_traffic=0                    # keep track of wifi traffic used today
prev_mobile_traffic=0                  # keep track of mobile traffic used today
MAX_MOBILE_GB=4                        # maximum mobile data usage per day
testing="false"                        # keep track if we are testing or not 
strike=0                               # keep time of how many times in a row high CPU was detected 
vrs="1.95"                             # code version 
max_screen_timeout="2147483647"        # do not turn off screen 

# check if testing
if [ $# -eq 1 ] 
then 
	testing="true"
fi 

# coin toss to select which port to use 
FLIP=$(($(($RANDOM%10))%2))
if [ $FLIP -eq 1 ]
then
	SERVER_PORT=8082
else 
	SERVER_PORT=8083
fi
myprint "Web-app port selected: $SERVER_PORT"
echo "$SERVER_PORT" > ".server_port"

# make sure only this instance of this script is running
my_pid=$$
app="stateupdate"
myprint "My PID: $my_pid"
ps aux | grep "$0" | grep "bash" > ".ps-$app"
N=`cat ".ps-$app" | wc -l`
if [ $N -gt 1 ]
then
    while read line
    do
        pid=`echo "$line" | awk '{print $2}'`
        if [ $pid -ne $my_pid ]
        then
            myprint "WARNING. Found a pending process for $0. Killing it: $pid"
            kill -9 $pid
        fi
    done < ".ps-$app"
fi

# # always make sure screen is in portrait -- does not carry over time 
# myprint "Ensuring that screen is in portrait and auto-rotation disabled"
# sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
# sudo  settings put system user_rotation 0          # put in portrait

# update Google account authorization status
t_last_google=0
current_time=`date +%s`
if [ -f ".time_google_check" ]
then 
	t_last_google=`cat ".time_google_check"`
fi 
let "t_p = current_time - t_last_google"
if [ $t_p -gt $GOOGLE_CHECK_FREQ ]
then
	myprint "Time to check Google account status via YT ($t_p > $GOOGLE_CHECK_FREQ)"
	check_account_via_YT	  
	t_last_google=$current_time		
	if [ $youtube_error == "false" ]
	then
		echo $current_time > ".time_google_check"
		myprint "Google account status: $google_status"	
	else 
		let "t_new = current_time - GOOGLE_CHECK_FREQ + 3600"
		myprint "Issued verifying account via YouTube. Will retry in one hour ($current_time => $t_new)" 		
		echo $current_time > ".time_google_check"		
	fi 
else
	myprint "Skipping Google account check - was done $t_p seconds ago!"
fi 
google_status=`cat ".google_status"`
	
# update code 
myprint "Updating our code..."
git pull

# start CPU monitoring (background)
./monitor-cpu.sh &

# ensure that BT is enabled 
myprint "Make sure that BT is running" 
bt_status=`sudo settings get global bluetooth_on`
if [ $bt_status -ne 1 ] 
then 
	myprint "Activating BT" 
	sudo service call bluetooth_manager 6
else 
	myprint "BT is active: $bt_status"
fi 

# retrieve unique ID for this device and pass to our app
physical_id="N/A"
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
if [ -f "uid-list.txt" ] 
then 
	physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | cut -f 1`
fi 
myprint "IMEI: $uid PhysicalID: $physical_id"

# status update
echo "true" > ".status"
to_run=`cat ".status"`
sudo cp ".status" "/storage/emulated/0/Android/data/com.example.sensorexample/files/status.txt"

#restart Kenzo - so that background service runs and info is populated 
turn_device_on
echo -e "$uid\t$physical_id" > ".temp"
sudo cp ".temp" "/storage/emulated/0/Android/data/com.example.sensorexample/files/uid.txt"
myprint "Granting Kenzo permission and restart..."
sudo pm grant $kenzo_pkg android.permission.ACCESS_FINE_LOCATION
sudo pm grant $kenzo_pkg android.permission.READ_PHONE_STATE
sudo monkey -p $kenzo_pkg 1 > /dev/null 2>&1
sleep 5
foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
myprint "Confirm Kenzo is in the foregound: $foreground" 
sudo cp ".temp" "/storage/emulated/0/Android/data/com.example.sensorexample/files/uid.txt"

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
if [ ! -f ".net_status" ] 
then
	echo "false" > ".net_status"
fi 
clean_file ".locked"

# make sure SELinux is permissive
ans=`sudo getenforce`
myprint "SELinux: $ans"
if [ $ans == "Enforcing" ]
then
    myprint "Disabling SELinux"
    sudo setenforce 0
    sudo getenforce
fi

# set NTP server #TOCHECK 
#sudo settings put global ntp_server pool.ntp.org

# find termuxt user 
termux_user=`whoami`

#close all and turn off screen
close_all
sudo input keyevent 111
turn_device_off

# always check connectivity on first run 
update_wifi_mobile

# external loop 
sel_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/selection.txt"
user_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/running.txt"	
myprint "Script will run with a <$fast_freq, $slow_freq> frequency. To stop: <<echo \"false\" > \".status\""
last_loop_time=0
last_slow_loop_time=0
firstPause="true"
while [ $to_run == "true" ] 
do 
	# keep track of time
	current_time=`date +%s`
	suffix=`date +%d-%m-%Y`
	
	# check if net-testing is running
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`			
	
	# update WiFi and mobile phone connectivity if it is time to do so (once a minute)
	let "t_last_wifi_mobile_update =  current_time - t_wifi_mobile_update"
	if [ $t_last_wifi_mobile_update -gt 60 ] 
	then 
		update_wifi_mobile 
		t_wifi_mobile_update=`date +%s`
	fi 
	
	# check if user wants us to pause 
	user_status="true"
	if [ -f $user_file ] 
	then 
		user_status=`sudo cat $user_file`
	fi 
	if [ $user_status == "false" ] 
	then 
		if [ $firstPause == "true" ]
		then
			firstPause="false"
			./stop-net-testing.sh
			clean_file ".locked"

			t_start_pause=`date +%s`
			myprint "Paused by user! Time: $t_start_pause"
			
			if [ $def_iface == "none" ] 
			then
				myprint "Skipping report sending since not connected"
			else 
				myprint "Data to send to the server:"			
				msg="PAUSED-BY-USER"			
				echo "$(generate_post_data_short)" 		
				timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data_short)" https://mobile.batterylab.dev:$SERVER_PORT/status
			fi 
		fi 
		echo "true" > ".isPaused"
	else 
		firstPause="true"
		t_start_pause=`date +%s`	
		echo "false" > ".isPaused"	
	fi 
	
	# check if user wants to run a test 
	if [ -f $sel_file ] 
	then 
		sel_id=`sudo cat $sel_file | cut -f 1`
		time_sel=`sudo cat $sel_file | cut -f 2`
		let "time_from_sel = current_time - time_sel"
		let "time_check = slow_freq + slow_freq/2" # cut some slack, we check more often than this
		if [ $time_from_sel -lt $time_check ]  
		then 
			myprint "User entered selection: $sel_id (TimeSinceSel:$time_from_sel)" #{"OPEN A WEBPAGE", "WATCH A VIDEO", "JOIN A VIDEOCONFERENCE"};
			if [ $def_iface != "none" ] 
			then
				case $sel_id in
					"0")
						# make sure no other test is running
						./stop-net-testing.sh
						clean_file ".locked"

						# update wifi/mobile info
						update_wifi_mobile 
						t_wifi_mobile_update=`date +%s`	
						
						# open a random webpage 
						myprint "Open a random webpage -- ./web-test.sh  --suffix $suffix --id $time_sel-"user" --iface $def_iface --single --pcap"
						./web-test.sh  --suffix $suffix --id $time_sel-"user" --iface $def_iface --single --pcap
						am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es rateid $time_sel --es accept "Please-rate-how-quickly-the-page-loaded:1-star-(slow)--5-stars-(fast)"
						;;

					"1")
						./stop-net-testing.sh
						clean_file ".locked"
						update_wifi_mobile 
						t_wifi_mobile_update=`date +%s`	
						myprint "Watch a video -- ./youtube-test.sh --suffix $suffix --id $time_sel-"user" --iface $def_iface --pcap --single"						
						./youtube-test.sh --suffix $suffix --id $time_sel-"user" --iface $def_iface --pcap --single
						am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es rateid $time_sel --es accept "Please-rate-how-the-video-played:1-star-(poor)--5-stars-(great)"
						;;
					  *)
						echo "Option not supported"
						;;
				esac
			else 
				am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Please-make-sure-the-device-is-on-line!"
			fi  
		else
			# removing selection file, no need to check all the time
			myprint "Cleaning old user selection file already used. (TimeSinceSel:$time_from_sel)"
			sudo rm $sel_file			 
		fi 
	fi 

	# loop rate control (fast)
	current_time=`date +%s`
	let "t_p = fast_freq - (current_time - last_loop_time)"
	if [ $t_p -gt 0 ] 
	then 
		sleep $t_p
	fi 
	to_run=`cat ".status"`
	sudo cp ".status" "/storage/emulated/0/Android/data/com.example.sensorexample/files/status.txt"
	current_time=`date +%s`
	last_loop_time=$current_time

	# check if phone was paused for too long
	let "t_since_paused = current_time - t_start_pause"
	if [ $t_since_paused -gt $MAX_PAUSE ]	
	then 
		echo "true" > ".temp" 
		sudo cp ".temp" $user_file
		echo "false" > ".isPaused"		
		myprint "UN-PAUSING since we have been paused for too long ($t_since_paused >= $MAX_PAUSE)!"
	fi 
	
	#if we are paused we stop here	
	isPaused=`cat ".isPaused"`
	if [ $isPaused == "true" ]
	then
		continue
	fi 
		
	# update Google account authorization status
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`
	t_last_google=`cat ".time_google_check"`
	let "t_p = current_time - t_last_google"
	if [ $t_p -gt $GOOGLE_CHECK_FREQ -a $num -eq 0 -a $asked_to_charge == "false" ] 
	then
		myprint "Time to check Google account status via YT ($t_p > $GOOGLE_CHECK_FREQ)"	
		check_account_via_YT	  
		t_last_google=$current_time
		echo $current_time > ".time_google_check"
		myprint "Google account status: $google_status"	
	fi 
	
	# loop rate control (slow)
	let "t_p = (current_time - last_slow_loop_time)"
	if [ $t_p -lt $slow_freq ] 
	then 
		continue
	fi 
	last_slow_loop_time=$current_time

	# check if there is a new command to run
	if [ $def_iface != "none" ] 
	then	
		prev_command="none"
		if [ -f ".prev_command" ] 
		then
			prev_command=`cat ".prev_command"`
		fi 
		t_curl_start=`date +%s`
		ans=`timeout 15 curl -s "https://mobile.batterylab.dev:$SERVER_PORT/action?id=${uid}&prev_command=${prev_command}&termuxUser=${termux_user}"`		
		ret_code=$?
		t_curl_end=`date +%s`
		let "curl_duration = t_curl_end - t_curl_start"		
		myprint "Checking if there is a command to execute. ANS:$ans - RetCode: $ret_code - Duration:$curl_duration"	
		if [[ "$ans" != *"No command matching"* ]]
		then		 	
			if [ $ret_code -eq 0 ]
			then 
				command=`echo $ans  | cut -f 1 -d ";"`
				comm_id=`echo $ans  | cut -f 3 -d ";"`
				duration=`echo $ans  | cut -f 4 -d ";" | sed 's/ //g'`	
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
					ans=`timeout 15 curl -s "https://mobile.batterylab.dev:$SERVER_PORT/commandDone?id=${uid}&command_id=${comm_id}&status=${comm_status}&termuxUser=${termux_user}"`
					myprint "Informed server about last command run. ANS: $ans"
				fi 
				echo $comm_id > ".prev_command"
			else 
				myprint "CURL error ($ret_code (124:TIMEOUT))"
			fi 
		else 
			myprint "Command not found ($ans)"
		fi 
	fi 

	# check CPU usage 
	if [ -f ".cpu-usage" ] 
	then 
		cpu_util=`cat ".cpu-usage" | cut -f 1 -d "."`
		if [ ! -z $cpu_util ]
		then 			
			if [ $cpu_util -ge 85 ] 
			then 
				if [ $num -eq 0 ]
				then 
					let "strike++"
					if [ $strike -eq 6 ] 
					then 
						#myprint "Detected high CPU (>85%) in the last 90 seconds. Rebooting"
						myprint "Detected high CPU (>85%) in the last 90 seconds.  -- Temporarily disabling rebooting"
						#sudo reboot 
					fi 
				else 
					myprint "Detected high CPU ($cpu_util>85%). Ignoring since we are net-testing"
				fi 
			else 
				strike=0
			fi 
			myprint "CPU usage: $cpu_util StrikeCount: $strike NetTesting: $num"
		fi 
	fi 

	# check if our foreground/background service is still running
	N_kenzo=`sudo ps aux | grep "com.example.sensor" | grep -v "grep" | grep -v "curl" | wc -l `
	if [ $N_kenzo -eq 0 ] 
	then 
		myprint "BT background process (kenzo service) was stopped. Restarting!"
		sudo monkey -p $kenzo_pkg 1 > /dev/null 2>&1
		sleep 5
		close_all
	fi 

	# get simple stats
	free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
	mem_info=`free -m | grep "Mem" | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`
	foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`

	# get phone battery level and ask to charge if needed # TBD
	sudo dumpsys battery > ".dump"
	phone_battery=`cat ".dump" | grep "level"  | cut -f 2 -d ":"`
	charging=`cat ".dump" | grep "AC powered"  | cut -f 2 -d ":"`
	if [ $phone_battery -lt 15 -a $charging == "false" ] 
	then 
 		if [ $asked_to_charge == "false" ] 
		then 
			myprint "Phone battery is low. Asking to recharge!"
			#termux-notification -c "Please charge your phone!" -t "recharge" --icon warning --prio high --vibrate pattern 500,500
			./stop-net-testing.sh
			sleep 5 
			turn_device_on
			am start -n com.example.sensorexample/com.example.sensorexample.MainActivity --es accept "Phone-battery-is-low.-Consider-charging!"
			asked_to_charge="true"
			msg="ASKED-TO-CHARGE"
			echo "$(generate_post_data_short)" 		
			timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data_short)" https://mobile.batterylab.dev:$SERVER_PORT/status
			sudo settings put system screen_off_timeout $max_screen_timeout		
			myprint "Testing skipping the rest since paused..."		
		fi 
		
		# check if it is time to status report (while "asked to charge")
		if [ -f ".last_report" ] 
		then 
			last_report_time=`cat ".last_report"`
		fi 
		let "time_from_last_report = current_time - last_report_time"
		myprint "Time from last report: $time_from_last_report sec"			 
		if [ $time_from_last_report -gt $REPORT_INTERVAL ] 
		then
			# make sure we have fresh wifi/mobile info		 
			update_wifi_mobile 
			t_wifi_mobile_update=`date +%s`	
							
			# dump location information without running googlemaps
			update_location
			
			# get uptime
			uptime_info=`uptime`

			if [ $def_iface == "none" ] 
			then
				myprint "Skipping report sending since not connected"
			else 
				myprint "Data to send to the server:"
				echo "$(generate_post_data)"
				t_curl_start=`date +%s`			
				timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/status
				t_curl_end=`date +%s`
				let "curl_duration = t_curl_end - t_curl_start"
				myprint "CURL duration POST: $curl_duration"
			fi 
			echo $current_time > ".last_report"
		fi 

		# block everything
		continue
	else 
 		if [ $asked_to_charge == "true" ] 
		then
			msg="IN-CHARGE"
			echo "$(generate_post_data_short)" 		
			timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data_short)" https://mobile.batterylab.dev:$SERVER_PORT/status
		fi 
		sudo settings put system screen_off_timeout 60000
		asked_to_charge="false"
	fi 

	# check if it is time to run net experiments 
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`	
	if [ -f ".last_net" ] 
	then 
		last_net=`cat ".last_net"`
	else 
		last_net=0
	fi
	if [ -f ".last_net_short" ] 
	then 
		last_net_short=`cat ".last_net_short"`
	else 
		last_net_short=0
	fi
	if [ -f ".last_net_forced" ] 
	then 
		last_net_forced=`cat ".last_net_forced"`
	else 
		last_net_forced=0
	fi 
	net_status=`cat ".net_status"`
	let "time_from_last_net = current_time - last_net"
	let "time_from_last_net_short = current_time - last_net_short"
	let "time_from_last_net_forced = current_time - last_net_forced"	
	
	# check if we are locked 
	locked="false"
	if [  -f ".locked" ]
	then 
		locked="true"
	fi 

	# logging 
	myprint "TimeFromLastNetLong:$time_from_last_net sec TimeFromLastNetShort:$time_from_last_net_short sec TimeFromLastNetForced:$time_from_last_net_forced sec ShouldRunIfTime:$net_status RunningNetProc:$num LockedStatus:$locked"
	
	# 1) flag set, 2) no previous running, 3) connected (basic checks to see if we should run)
	if [ $net_status == "true" -a $num -eq 0 -a $def_iface != "none" -a $locked == "false" ]  
	then
		# update counter of how many runs today 
		curr_hour=`date +%H`
		num_runs_today=0
		if [ -f ".zus-${suffix}" ]
		then
			num_runs_today=`cat ".zus-${suffix}"`
		fi 	

		# condition-1: encountered a new wifi (hopefully plane)
		force_net_test=`cat ".force_counter"`

		if [ $force_net_test -gt 0 -a $time_from_last_net_forced -gt $NET_INTERVAL_FORCED ] 
		then
			myprint "Forcing a net test on new wifi: $time_from_last_net_forced > $NET_INTERVAL_FORCED  -- NumRunsLeft: $force_net_test DefaultIface:$def_iface SSID:$wifi_ssid"
			update_wifi_mobile 
			t_wifi_mobile_update=`date +%s`
			if [ ! -z $wifi_iface ]
			then	 	  	    
				myprint "./net-testing.sh $suffix $current_time $def_iface \"long\" > logs/net-testing-forced-`date +\%m-\%d-\%y_\%H:\%M`.txt"
				(timeout 1200 ./net-testing.sh $suffix $current_time $def_iface "long" > logs/net-testing-forced-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &)
				num=1
				echo $current_time > ".last_net"
				echo $current_time > ".last_net_short"
				let "force_net_test--"
				echo $force_net_test > ".force_counter"
				echo $current_time > ".last_net_forced"
			else 
				myprint "Skipping forced net-testing since WiFi not found anymore"
			fi 
		fi 
		
		# condition-2: it is time! (long freq, for both wifi and mobile)
		if [ $num -eq 0 -a $time_from_last_net -gt $NET_INTERVAL ] 
		then 
			myprint "Time to run LONG net-test: $time_from_last_net > $NET_INTERVAL -- DefaultIface:$def_iface NumRuns:$num_runs_today MobileData:$mobile_data (MAX: $MAX_MOBILE)"
			skipping="false"
			update_wifi_mobile 
			t_wifi_mobile_update=`date +%s`
			if [ ! -z $mobile_iface ]
			then
	 	  	    # if enough mobile data is available 
				if [ $def_iface == $mobile_iface -a $mobile_data -gt $MAX_MOBILE ]   
				then 
					myprint "Skipping net-testing since we are on mobile and data limit was passed ($mobile_data -> $MAX_MOBILE)"
					skipping="true"
				fi 
			fi  
			if [ $skipping == "false" ]
			then
				myprint "./net-testing.sh $suffix $current_time $def_iface \"long\" > logs/net-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt"
				(timeout 1200 ./net-testing.sh $suffix $current_time $def_iface "long"> logs/net-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &)
				num=1
				echo $current_time > ".last_net"
				echo $current_time > ".last_net_short"			
			fi
		fi 
		
		# condition-3: we are on mobile only and did not do more than N test yet today # FIXME 
		if [ $num -eq 0 -a $time_from_last_net_short -gt $NET_INTERVAL_SHORT ] 
		then
			skipping="false"
			update_wifi_mobile 
			t_wifi_mobile_update=`date +%s`			
			if [ ! -z $mobile_iface ] 
			then 
				if [ $def_iface != $mobile_iface -o $num_runs_today -ge $MAX_ZEUS_RUNS  -o $mobile_data -gt $MAX_MOBILE ] 
				then 
					myprint "Skipping net-testing-short. DefaultIface:$def_iface NumRuns:$num_runs_today MobileData:$mobile_data (MAX: $MAX_MOBILE)"
					skipping="true"
				fi 
			else
				myprint "Skipping net-testing-short since not on mobile at all"				 
				skipping="true"
			fi
			if [ $skipping == "false" ]
			then
				myprint "Time to run SHORT test: $time_from_last_net > $NET_INTERVAL_SHORT -- DefaultIface:$def_iface NumRuns:$num_runs_today MobileData:$mobile_data (MAX: $MAX_MOBILE)"
				myprint "./net-testing.sh $suffix $current_time $def_iface \"short\" > logs/net-testing-short-`date +\%m-\%d-\%y_\%H:\%M`.txt"
				(timeout 1200 ./net-testing.sh $suffix $current_time $def_iface "short" > logs/net-testing-short-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &)
				num=1
				echo $current_time > ".last_net_short"
			fi
		fi 
	else
		myprint "Skipping net-testing. NetStatus:$net_status NumNetProc:$num DefIface:$def_iface LockedStatus:$locked"
	fi 
	
	# check if it is time to status report
	if [ -f ".last_report" ] 
	then 
		last_report_time=`cat ".last_report"`
	fi 
	let "time_from_last_report = current_time - last_report_time"
	myprint "Time from last report: $time_from_last_report sec"
	if [ $testing == "true" ] 
	then 
		myprint "Since testing, forcing time-from-last-report to 180000"
		time_from_last_report=18000
	fi 
	if [ $time_from_last_report -gt $REPORT_INTERVAL ] 
	then
		# make sure we have fresh wifi/mobile info		 
		update_wifi_mobile 
		t_wifi_mobile_update=`date +%s`	
						
		# dump location information (only start googlemaps if not net-testing to avoid collusion)
		if [ ! -f ".locked" ]  # NOTE: this means that another app (browser, youtube, videoconf) is already running!
		then 
			skip_gmaps="false"
			last_gmaps=0
			if [ -f ".last_gmaps" ] 
			then 
				last_gmaps=`cat ".last_gmaps"`
			fi 
			let "time_from_last_gmaps = current_time - last_gmaps"	
			if [ ! -z $wifi_iface ] # Reduce gmaps launching rate when on WiFi
			then  
				# compute time from last check 
				if [ $time_from_last_gmaps -lt $WIFI_GMAPS ] 
				then 
					skip_gmaps="true"
				fi 
			fi 
			if [ $skip_gmaps == "false" ]
			then 
				turn_device_on
				myprint "Launching googlemaps to improve location accuracy - DefInterface: $def_iface - (TimeLastGmap:$time_from_last_gmaps (Max: $WIFI_GMAPS)"
				sudo monkey -p com.google.android.apps.maps 1 > /dev/null 2>&1
				sleep 5 
				foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
				myprint "Confirm Maps is in the foregound: $foreground" 
				# needed in case maps ask for storage...
				sudo input tap 108 1220
				sleep 10
				close_all
				turn_device_off
				echo `date +%s` > ".last_gmaps"
			else 
				myprint "Skipping gmaps launch since on wifi and lower freq not met ($time_from_last_gmaps -lt $WIFI_GMAPS)"
			fi 
		fi 

		# update location info
		update_location

		# get uptime
		uptime_info=`uptime`

		if [ $def_iface == "none" ] 
		then
			myprint "Skipping report sending since not connected"
		else 
			
			myprint "Data to send to the server:"
			echo "$(generate_post_data)"
			t_curl_start=`date +%s`	
			timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/status
			t_curl_end=`date +%s`
			let "curl_duration = t_curl_end - t_curl_start"
			myprint "CURL duration POST: $curl_duration"
		fi 
		echo $current_time > ".last_report"
	fi 
	
	# stop here if testing 
	if [ $testing == "true" ] 
	then
		myprint "One simple test was requested, interrupting!" 
		break
	fi 
done

# logging 
echo "false" > ".cpu_monitor"
./stop-net-testing.sh
clean_file ".locked"
myprint "A request to interrupt $0 was received and executed. All good!"
