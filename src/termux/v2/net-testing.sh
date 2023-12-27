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

run_network_tests(){
	linkPropertiesFile="/storage/emulated/0/Android/data/com.example.sensorexample/files/linkProperties.txt"
	iface=`su -c cat "$linkPropertiesFile" | cut -f 2 -d " " | head -n 1`

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
			( ./v2/youtube-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single ) & exp_pid=$! 
			watch_test_timeout $exp_pid 2>/dev/null
		else 
			( ./v2/youtube-test-kiwi.sh --suffix $suffix --id $t_s --iface $iface --pcap --single ) & exp_pid=$! 
			watch_test_timeout $exp_pid 2>/dev/null
		fi
		myprint "Sleep 30 after Youtube-test to lower CPU load..."
		sleep 30  	
	else 
		myprint "Skipping YouTube testing option:$opt"
	fi 

	# run multiple MTR
	( ./mtr.sh $suffix $t_s ) & exp_pid=$! 
	watch_test_timeout $exp_pid 2>/dev/null

	# run a speedtest 
	( ./v2/speed-test.sh --suffix $suffix --id $t_s ) & exp_pid=$!
	watch_test_timeout $exp_pid 2>/dev/null
	myprint "Sleep 30 after speed-test to lower CPU load..."
	sleep 30

	# test multiple CDNs
	( ./cdn-test.sh $suffix $t_s ) & exp_pid=$!
	watch_test_timeout $exp_pid 2>/dev/null
	myprint "Sleep 30 after CDN-test to lower CPU load..."
	sleep 30

	# test multiple webages -- TEMPORARILY DISABLED 
	if [ $opt == "long" ] 
	then
	( ./v2/web-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single ) & exp_pid=$! 
	watch_test_timeout $exp_pid 2>/dev/null
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
	turn_device_off
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
                    while [[ "$currentNetwork" != *"$networkToTest"* ]];
                    do
                        turn_device_on
                        su -c cmd statusbar expand-settings
                        sleep 1 
                        sudo input tap 850 1250
                        sleep 1 
                        sudo input tap 850 $((1000+$i*250))
                        sleep 7
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

currentNetwork=`get_network_type`
if [[ "$currentNetwork" == "WIFI_true"* ]];then
	run_network_tests
elif [[ "$currentNetwork" == "WIFI_false"* ]];then
	myprint "Unable to run $1 due to no internet connection with current WIFI"
elif [[ "$currentNetwork" == *"true"* ]];then
    subscriptions_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/subscriptions.txt"
    if sudo [ -f $subscriptions_file ]; then
        numSubs=`su -c cat $subscriptions_file | wc -l`
		if [ $numSubs -gt 0 ];then
			for ((i=1;i<=numSubs;i++))
			do
				# 1. switch sim 
				myprint "Switching Data Plan - Step 1"
				networkToTest=`su -c cat $subscriptions_file | head -n $i | tail -1`
				while [[ "$currentNetwork" != *"$networkToTest"* ]];
				do
					turn_device_on
					su -c cmd statusbar expand-settings
					sleep 1 
					sudo input tap 850 1250
					sleep 1 
					sudo input tap 850 $((1000+$i*250))
					sleep 7
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
				myprint "Switching Data Plan - Step 2"
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
				myprint "Switching Data Plan - Step 3"
				myprint "Running network tests in $currentNetwork"
                networkProperties=`get_network_properties`
                myprint "$networkProperties"
				run_network_tests
				myprint "Done with network tests on $currentNetwork $iface. Sleeping for 30 seconds"
				sleep 30
			done
		fi 
	fi
else
	myprint "Unable to run $1 due to no internet connection"  
fi

rm ".locked"
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