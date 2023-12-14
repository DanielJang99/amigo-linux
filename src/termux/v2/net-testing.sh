#!/data/data/com.termux/files/usr/bin/env bash
# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	./stop-net-testing.sh
}

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "mobile_IP":"${mobile_ip}",
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "net":"${net}",
    "mServiceState":"${mServiceState}",
    "data_Used":"${data_used}",        
    "msg":"${msg}"
    }
EOF
}

# switch to 5G or Lte 
switch_network(){
    su -c am start com.samsung.android.app.telephonyui/com.samsung.android.app.telephonyui.netsettings.ui.NetSettingsActivity
    sleep 4
    tap_screen 500 900 1 

    if [[ $1 == "5G" ]];then
        tap_screen 500 900 1
    else
        tap_screen 500 1000 1
    fi
}

# kill a test if it runs more than 5 minutes 
watch_test_timeout(){
    ( sleep $TEST_TIMEOUT && sudo kill -9 $1 ) 2>/dev/null & watcher=$!
    if wait $1 2>/dev/null; then
        sudo kill -9 $watcher
        wait $watcher
        sleep_pid=`ps aux | grep "sleep 300" | head -n 1 | awk '{print $2}'`
        sudo kill -9 $sleep_pid
        myprint "Test completed"
    else
        myprint "Test process killed after running for 5 minutes"
    fi
}

run_experiment(){
    currentNetwork=`get_network_type`
    if [[ "$currentNetwork" == "WIFI_true"* ]];then
        run_experiment_on_wifi "$1"
    elif [[ "$currentNetwork" == "WIFI_false"* ]];then
        myprint "Unable to run $1 due to no internet connection with current WIFI"
    elif [[ "$currentNetwork" == *"true"* ]];then
        run_experiment_across_sims "$1"
    else
        myprint "Unable to run $1 due to no internet connection"  
    fi
}

run_experiment_on_wifi(){
    myprint "Running in WIFI: $1"
    networkProperties=`get_network_properties`
    myprint "$networkProperties"
    ( $1 ) & exp_pid=$! 
    watch_test_timeout $exp_pid 2>/dev/null
}

# run an experiment on esim, sim_lte, sim_5g (if possible)
run_experiment_across_sims(){
    subscriptions_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/subscriptions.txt"
    if sudo [ -f $subscriptions_file ]; then
        numSubs=`su -c cat $subscriptions_file | wc -l`
        if [ $numSubs -gt 0 ]
        then 
            currentNetwork=`get_network_type`
            if [ ! -z "$currentNetwork" ]
            then
                for ((i=1;i<=numSubs;i++))
                do
                    # 1. switch sim 
                    networkToTest=`su -c cat $subscriptions_file | head -n $i | tail -1`
                    while [[ "$currentNetwork" != "$networkToTest"* ]];
                    do
                        turn_device_on
                        su -c cmd statusbar expand-settings
                        sleep 1 
                        sudo input tap 850 1250
                        sleep 1 
                        sudo input tap 850 $((1000+$i*250))
                        sleep 3
                        sudo input keyevent KEYCODE_APP_SWITCH
                        sleep 0.5
                        sudo input keyevent KEYCODE_BACK
                        sleep 1
                        currentNetwork=`get_network_type`
                        if [[ "$currentNetwork" == "WIFI"* ]];then
                            myprint "Network has switched from mobile to WIFI"
                            return
                        fi
                    done
                    turn_device_off

                    #2. check internet connectivity after selecting sim - 10 seconds
                    numFails=0
                    while [[ "$currentNetwork" == *"false"* && $numFails -lt 20 ]];
                    do
                        sleep 0.5 
                        currentNetwork=`get_network_type`
                        let "numFails++"
                    done
                    if [[ "$currentNetwork" == *"false"* ]];then
                        myprint "Unable to run $1 due to no internet connection with current mobile data: $currentNetwork"
                        continue
                    fi

                    #3. run test 
                    myprint "Running in $currentNetwork"
                    networkProperties=`get_network_properties`
                    myprint "$networkProperties"
                    ( $1 ) & exp_pid=$! 
                    watch_test_timeout $exp_pid 2>/dev/null
                done
            fi
        else 
            myprint "Error running experiment in mobile data: no active subscriptions"
        fi
    else 
        myprint "Error running experiment in mobile data: missing subscription file"
    fi
}


# run NYU measurement 
run_zus(){
	# params and folder organization
	server_ip="212.227.209.11"
	res_dir="zus-logs/$suffix"
	mkdir -p $res_dir
	mobile_ip=`ifconfig $mobile_iface | grep "\." | grep -v "packets" | awk '{print $2}'`
	
	#switch to 3G 
	traffic_start=`ifconfig $mobile_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
	myprint "NYU-stuff. Switch to 3G"	
    if [ -f ".uid" ]
    then 
        uid=`cat ".uid" | awk '{print $2}'`
        physical_id=`cat ".uid" | awk '{print $1}'`
    else 
        uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
        if [ -f "uid-list.txt" ] 
        then 
            physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | awk '{print $1}'`
        fi 
    fi
	myprint "UID: $uid PhysicalID: $physical_id"
	turn_device_on
	am start -n com.samsung.android.app.telephonyui/com.samsung.android.app.telephonyui.netsettings.ui.simcardmanager.SimCardMgrActivity
	sleep 5 
	
	# take screenshot of network settings and upload to our server 
	sudo screencap -p "network-setting-last.png"
	sudo chown $USER:$USER "network-setting-last.png"
	cwebp -q 80 "network-setting-last.png" -o "network-setting-last.webp" > /dev/null 2>&1 
	if [ -f "network-setting-last.webp" ]
	then 
		chmod 644 "network-setting-last.webp"
		rm "network-setting-last.png"
	fi
	remote_file="/root/mobile-testbed/src/server/network-settings/${physical_id}.webp" 
	(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no "network-setting-last.webp" root@23.235.205.53:$remote_file > /dev/null 2>&1 &)
	
	# enter and select either 3G or 4G
	tap_screen 370 765 5
	tap_screen 370 765 5 
	tap_screen 370 660 2
	sudo input keyevent KEYCODE_BACK  
	close_all
	turn_device_off
	myprint "./FTPClient $server_ip 8888 $uid 3G $ZEUS_DURATION"
	timeout 150 ./FTPClient $server_ip 8888 $uid 3G $ZEUS_DURATION
	net="3G"
	mServiceState=`sudo dumpsys telephony.registry | grep "mServiceState" | head -n 1`	
	traffic_end=`ifconfig $mobile_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
	let "data_used = traffic_end - traffic_start"
	if [ -f zeus.csv ]
	then 
		msg=`head -n 1 zeus.csv`	
		mv zeus.csv "${res_dir}/${t_s}-3G.txt"
		gzip "${res_dir}/${t_s}-3G.txt"
	else 
		msg="ZEUS-4G-NOT-FOUND"
	fi 
	
	# send report to our server
	traffic_start=`ifconfig $mobile_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`	
	current_time=$t_s
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:$SERVER_PORT/zeustest

	#switch back to 4G 
	myprint "NYU-stuff. Switch to 4G"	
	echo "[`date`] starting NYU on 4G"
	turn_device_on
	am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
	sleep 5 
	tap_screen 370 765 5
	tap_screen 370 765 5
	tap_screen 370 560 2
	sudo input keyevent KEYCODE_BACK
	close_all
	turn_device_off
	myprint "./FTPClient $server_ip 8888 $uid 4G $ZEUS_DURATION"	
	timeout 150 ./FTPClient $server_ip 8888 $uid 4G $ZEUS_DURATION
	net="4G"	
	mServiceState=`sudo dumpsys telephony.registry | grep "mServiceState" | head -n 1`		
	traffic_end=`ifconfig $mobile_iface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
	let "data_used = traffic_end - traffic_start"	
	if [ -f zeus.csv ]
	then 
		msg=`head -n 1 zeus.csv`
		mv zeus.csv "${res_dir}/${t_s}-4G.txt"
		gzip "${res_dir}/${t_s}-4G.txt"
	else 
		msg="ZEUS-4G-NOT-FOUND"
	fi
	current_time=$t_s
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:$SERVER_PORT/zeustest
}

# params
skipZeus="true"
MAX_ZEUS_RUNS=6             # maximum duration of NYU experiments
ZEUS_DURATION=20            # duration of NYU experiments
MAX_LOCATION=5              # timeout of duration command
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
opt="long"
TEST_TIMEOUT=300
airplane_mode="false"
if [ $# -ge 4 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
	opt=$4

	# increase test timeout in airplane mode
	if [[ $5 == *"airplane"* ]]
	then
		airplane_mode="true"
		TEST_TIMEOUT=600
	fi
fi  

# retrieve last used server port 
if [ -f ".server_port" ] 
then 
	SERVER_PORT=`cat ".server_port"`
else 
	SERVER_PORT="8082"
fi 

#logging 
echo "[`date`] net-testing $opt START. SERVER_PORT:$SERVER_PORT -- $Sleeping 30 secs to propagate status"

# lock out google maps to avoid any interference
t_start=`date +%s`
touch ".locked" 
sleep 30 

# current free space 
free_space_s=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`

# Get Current DNS used 
if [ $opt == "long" ]
then
    myprint "Getting current DNS used - saved to dns-results/$suffix/$t_s.txt"
    dns_res_folder="dns-results/$suffix"
    mkdir -p $dns_res_folder
    networkProperties=`get_network_properties`
    myprint "$networkProperties"
    curl -L https://test.nextdns.io > "${dns_res_folder}/$t_s.txt"
fi

# video testing with youtube
# if [ $opt == "long" -a $airplane_mode == "false" ] 
if [ $opt == "long" ] 
then 
    if [ -f ".youtube_browser" ]
    then 
        yt_browser=`cat .youtube_browser`
        if [[ "$yt_browser" == "chrome"* ]]
        then
            run_in_chrome="true"
        fi
    fi
    
    if [[ "$run_in_chrome" == "true" ]]
    then 
        run_experiment "./v2/youtube-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single"
    else 
        run_experiment "./v2/youtube-test-kiwi.sh --suffix $suffix --id $t_s --iface $iface --pcap --single"
    fi
    myprint "Sleep 30 after Youtube-test to lower CPU load..."
    sleep 30  	
else 
	myprint "Skipping YouTube testing option:$opt"
fi 

# run multiple MTR
run_experiment "./mtr.sh $suffix $t_s"

# run nyu stuff -- only if MOBILE and not done too many already 
num_runs_today=0
if [ ! -f ".data" ] 
then
	sudo dumpsys netstats > .data
fi 
mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | grep "rmnet" | grep "true" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
mobile_iface=`cat .data | grep -A1 "All mobile interfaces" | grep "rmnet"`
if [ ! -z "$mobile_iface" ];then
	mobile_iface=`cat .data | grep "iface=rmnet" | grep "defaultNetwork=true" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
fi 
if [ ! -z $mobile_iface ] && [ $skipZeus == "false" ]
then 
	#  status update 
	curr_hour=`date +%H`
	status_file=".zus-${suffix}"
	if [ -f $status_file ]
	then
		num_runs_today=`cat $status_file`
	fi 	
	myprint "NYU-stuff. Found a mobile connection: $mobile_iface (DefaultConnection:$iface). NumRunsToday:$num_runs_today (MaxRuns: $MAX_ZEUS_RUNS)"
	if [ $iface == $mobile_iface -a $num_runs_today -lt $MAX_ZEUS_RUNS ] 
	then
		# make sure code is there (fix if not)
		if [ ! -f "FTPClient" ]
		then
			myprint "ERROR -- Missing FTPClient code, checking out!" 
			git checkout FTPClient
		fi 		
	
		##################### testing 
		myprint "Ensuring that screen is in portrait and auto-rotation disabled"
		sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
		sudo  settings put system user_rotation 0          # put in portrait
		##################### testing 
		
		run_zus		
		let "num_runs_today++"
		myprint "Done with zus. New count for the day: $num_runs_today"
		echo $num_runs_today > $status_file
		myprint "Sleep 30 to lower CPU load..."		
		sleep 30  		 
	else 
		myprint "NYU-stuff. Skipping since on WiFI!"
	fi 
else 
	myprint "No mobile connection found. Skipping NYU-ZUS"
fi 

# if on mobile, launch googlemaps which is now locked out on other process
if [ ! -z $mobile_iface ]
then 
	if [ $iface == $mobile_iface -a $num_runs_today -lt $MAX_ZEUS_RUNS ] 
	then 
		turn_device_on
		myprint "Launching googlemaps from net-testing since we are on mobile (and main process is holding back)"
		sudo monkey -p com.google.android.apps.maps 1 > /dev/null 2>&1
		sleep 15
		close_all
		turn_device_off
		res_dir="locationlogs/${suffix}"
		mkdir -p $res_dir		
		current_time=`date +%s`
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
		sleep 15 
	fi 
fi

# run a speedtest 
run_experiment "./v2/speed-test.sh --suffix $suffix --id $t_s"
myprint "Sleep 30 after speed-test to lower CPU load..."
sleep 30

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# test multiple CDNs
run_experiment "./cdn-test.sh $suffix $t_s"
myprint "Sleep 30 after CDN-test to lower CPU load..."
sleep 30

# QUIC test? 
# TODO 

# test multiple webages -- TEMPORARILY DISABLED 
if [ $opt == "long" ] 
then
run_experiment "./v2/web-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single" # reduced number of webpage tests
sleep 30 
else 
	myprint "Skipping WebTest testing option:$opt"
fi 

# safety cleanup 
sudo pm clear com.android.chrome
#sudo pm clear com.google.android.youtube
turn_device_on
close_all
sudo killall tcpdump
for pid in `ps aux | grep 'youtube-test\|web-test\|mtr.sh\|cdn-test.sh\|speedtest-cli'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do
    kill -9 $pid
done
rm ".locked"
turn_device_off

# current free space 
free_space_e=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
space_used=`echo "$free_space_s $free_space_e" | awk '{print($1-$2)*1000}'`

#logging 
t_end=`date +%s`
let "t_p = t_end - t_start"
echo "[`date`] net-testing $opt END. Duration: $t_p FreeSpace: ${free_space_e}GB SpaceUsed: ${space_used}MB"

######################### disable wifi for zeus testing after 6pm
# elif [ $curr_hour -ge 18 ] # we are past 6pm
	# then 
	# 	myprint "NYU-stuff. It is past 6pm and missing data. Resorting to disable WiFi (sleep 30 to allow state-update to know)"
	# 	touch ".locked"
	# 	sleep 30 
	# 	toggle_wifi "off" $iface
	# 	run_zus
	# 	toggle_wifi "on" $iface
	# 	myprint "Enabling WiFi back"		
	
	# 	# allow some time to rest 
	# 	myprint "Resting post ZEUS test..."
	# 	sleep 30