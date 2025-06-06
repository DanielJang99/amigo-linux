#!/bin/bash
## NOTE: report updates to the central server 
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-05-26

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	./stop-net-testing.sh
	clean_file ".locked"
	exit -1 
}

# import util file
DEBUG=1
util_file=`pwd`"/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

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
    "last_curl_dur":"${curl_duration}",
    "uid":"${uid}",
    "uptime":"${uptime_info}",
    "dish_location":"${dish_location}",
    "net_testing_proc":"${num}", 
    "def_iface":"${def_iface}", 
    "public_ip":"${public_ip}",
    "wifi_ssid":"${wifi_ssid}",
    "today_wifi_data":"${wifi_data}",
    "today_docker_data":"${docker_data}",
    "network_type": "${network_type}"
    }
EOF
}


# TODO: get GPS location from linux machine 
update_location(){
	today=`date +\%d-\%m-\%y`
	res_dir="/locationlogs/${today}.txt"
	if [ -f $res_dir ]
	then 
		dish_location=`tail -n 1 $res_dir`
	else
		dish_location="none"
	fi
}

update_network_status(){

	if [ -z $init_wifi_traffic ]
	then
		init_wifi_traffic=0
	fi
    wifi_today_file="./data/wifi/"$suffix".txt"
	if [ ! -f $wifi_today_file ]
	then
		wifi_data=0
	else
		wifi_data=`cat $wifi_today_file`
	fi

	if [ -z $init_docker_traffic ]
	then
		init_docker_traffic=`get_interface_data eth0`
	fi
	docker_today_file="./data/docker/"$suffix".txt"		
    if [ ! -f $docker_today_file ] 
    then 
        docker_data=0
    else
		docker_data=`cat $docker_today_file`
    fi

    def_iface=`get_def_iface`
    network_type=`check_network_status`
	wifi_ssid="none"
	public_ip="none"
    if [[ "$network_type" == *"true"* ]]
    then 
        public_ip=`get_public_ip`
        if [[ "$network_type" == *"wifi"* ]]
        then
			wifi_traffic=`get_interface_data $def_iface`
			wifi_data=$((wifi_traffic - init_wifi_traffic))
			myprint "Wifi traffic: $wifi_traffic - $init_wifi_traffic = $wifi_data"
        elif [[ "$network_type" == *"docker"* ]]
        then
			docker_traffic=`get_interface_data eth0`
			docker_data=$((docker_traffic - init_docker_traffic))
			myprint "Docker traffic: $docker_traffic - $init_docker_traffic = $docker_data"
        fi
    fi
	echo $wifi_data > $wifi_today_file
	echo $docker_data > $docker_today_file
	myprint "Device info. Wifi:$wifi_ssid WifiData:$wifi_data DockerData:$docker_data DefaultIface:$def_iface NetTesting:$num NetworkType:$network_type"
}


# parameters
slow_freq=30                           # interval for checking commands to run (slower)
fast_freq=5                            # interval for checking the app (faster)
#SERVER_PORT=8082                      # port of our web app
SERVER_PORT=8083                       # web app port (when debugging at server)
REPORT_INTERVAL=300                    # interval of status reporting (seconds)
NET_INTERVAL=3600                      # interval of networking testing 
last_report_time=0                     # last time a report was sent 
last_net=0                             # last time a net test was done  
t_wifi_update=0                        # last time wifi/mobile info was checked 
testing="false"                        # keep track if we are testing or not 
vrs="3.0"                              # code version for linux adaptation 
curl_duration="-1"                     # last value measured of curl duration
username=`whoami`
network_type=`check_network_status`
today=`date +\%d-\%m-\%y`
output_path="logs/$today"
mkdir -p $output_path
	
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

# update code 
myprint "Updating our code..."
git pull
if [ $? -ne 0 ]
then
	git stash 
	git pull
fi

# status update
echo "true" > ".status"
to_run=`cat ".status"`

# Read MAX_DOCKER_GB from config file, fallback to default if not found
CONFIG_FILE="/config/amigo.conf"
if [ -f "$CONFIG_FILE" ]; then
    myprint "Loading configuration from $CONFIG_FILE"
    
    # Parse the config file for key=value pairs
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^["'"'"']\|["'"'"']$//g')
        
        # Set variables based on key
        case "$key" in
            "MAX_DOCKER_GB")
                MAX_DOCKER_GB="$value"
                ;;
            "MAX_WIFI_GB")
                MAX_WIFI_GB="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
    
    myprint "Configuration loaded successfully"
fi

# Set defaults if not defined or empty
if [ -z "$MAX_DOCKER_GB" ]; then
    MAX_DOCKER_GB=1
    myprint "Warning: MAX_DOCKER_GB not found in config, using default: ${MAX_DOCKER_GB}GB"
fi
if [ -z "$MAX_WIFI_GB" ]; then
    MAX_WIFI_GB=10
    myprint "Warning: MAX_WIFI_GB not found in config, using default: ${MAX_WIFI_GB}GB"
fi

# derive B from GB
let "MAX_WIFI = MAX_WIFI_GB * 1000000000"
let "MAX_DOCKER = MAX_DOCKER_GB * 1000000000"

# folder and file organization 
mkdir -p "./logs"
mkdir -p "./data/wifi"
mkdir -p "./data/docker"

if [ ! -f ".last_command" ] 
then 
	echo "testing" > ".last_command"
fi 
if [ ! -f ".net_status" ] 
then
	echo "true" > ".net_status"
fi 
clean_file ".locked"

# set NTP server #TOCHECK 
#sudo settings put global ntp_server pool.ntp.org

# find termuxt user 
update_network_status

# external loop 
myprint "Script will run with a <$fast_freq, $slow_freq> frequency. To stop: <<echo \"false\" > \".status\""
last_loop_time=0
last_slow_loop_time=0
while [[ $to_run == "true" ]] 
do 

	# keep track of time
	current_time=`date +%s`
	suffix=`date +%d-%m-%Y`
	
	# check if net-testing is running
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`			
	
	# update WiFi and mobile phone connectivity if it is time to do so (once a minute)
	network_type=`check_network_status`	
	let "t_last_wifi_mobile_update =  current_time - t_wifi_update"
	if [ $t_last_wifi_mobile_update -gt 60 ] 
	then 
		update_network_status 
		t_wifi_update=`date +%s`
	fi 

	# loop rate control (fast)
	current_time=`date +%s`
	let "t_p = fast_freq - (current_time - last_loop_time)"
	if [ $t_p -gt 0 ] 
	then 
		sleep $t_p
	fi 
	to_run=`cat ".status"`
	current_time=`date +%s`
	last_loop_time=$current_time

	# loop rate control (slow)
	let "t_p = (current_time - last_slow_loop_time)"
	if [ $t_p -lt $slow_freq ] 
	then 
		continue
	fi 
	last_slow_loop_time=$current_time   

	# check if there is a new command to run
	if [[ $def_iface != "none" && $network_type == *"true"* ]] 
	then	
		prev_command="none"
		if [ -f ".prev_command" ] 
		then
			prev_command=`cat ".prev_command"`
		fi 
		t_curl_start=`date +%s`
		ans=`timeout 15 curl -s "https://mobile.batterylab.dev:$SERVER_PORT/action?id=${uid}&prev_command=${prev_command}&termuxUser=${username}"`		
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
				if [[ $prev_command == $comm_id ]] 
				then 
					myprint "Command not allowed since it matches last command run!!"
				else 
					if [[ $background == "true" ]] 
					then 
						eval timeout $duration $command & 
						comm_status=$?
						myprint "Command started in background. Status: $comm_status"
					else 
						# TODO: consider generalizing with a priority expressed in the command
						echo $command | grep "videoconf-tester.sh" > /dev/null
						if [ $? -eq 0 ] 
						then 
							myprint "Requested a videoconference. Making sure there is no pending net-testing"		
							./stop-net-testing.sh
						fi
						echo $command | grep "muzeel" > /dev/null
						if [ $? -eq 0 ] 
						then 
							myprint "Requested a muzeel test. Making sure there is no pending net-testing"		
							./stop-net-testing.sh
						fi 
						echo $command | grep "reboot" > /dev/null
						if [ $? -eq 0 ]
						then
							myprint "Rebooting Device"
							ans=`timeout 15 curl -s "https://mobile.batterylab.dev:$SERVER_PORT/commandDone?id=${uid}&command_id=${comm_id}&status=0&termuxUser=${username}"`
						fi
						eval timeout $duration $command
						comm_status=$?
						myprint "Command executed. Status: $comm_status"
					fi
					ans=`timeout 15 curl -s "https://mobile.batterylab.dev:$SERVER_PORT/commandDone?id=${uid}&command_id=${comm_id}&status=${comm_status}&termuxUser=${username}"`
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


	# check if it is time to run net experiments 
	num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`	
	if [ -f ".last_net" ] 
	then 
		last_net=`cat ".last_net"`
	else 
		last_net=0
	fi
	net_status=`cat ".net_status"`
	let "time_from_last_net = current_time - last_net"
	
	# check if we are locked 
	locked="false"
	if [  -f ".locked" ]
	then 
		locked="true"
	fi 

	# force net-test if last iteration was over 2 hours ago
	if [[ $time_from_last_net -gt 7200 ]]; then
		net_test_pid=`ps aux | grep ".net-testing.sh" | grep -v "grep" | grep -v "timeout" | awk '{print $2}' | head -n 1`
		if [ ! -z "$net_test_pid" ];then
			myprint "Killing zombie net-test processes"
			sudo kill -9 "$net_test_pid"
		fi
		sleep 1 
		num=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`			

		if [[ $locked == "true" ]];then
			clean_file ".locked"
			locked="false"
		fi
	fi

	# logging 
	myprint "TimeFromLastNetLong:$time_from_last_net sec ShouldRunIfTime:$net_status RunningNetProc:$num LockedStatus:$locked"

	# 1) flag set, 2) no previous running, 3) connected (basic checks to see if we should run) 
	if [[ $num -eq 0 && $def_iface != "none" && $locked == "false" && $network_type == *"true"* && $time_from_last_net -gt $NET_INTERVAL ]]
	then
        myprint "Time to run LONG net-test: $time_from_last_net > $NET_INTERVAL -- DefaultIface:$def_iface"
        skipping="false"
        update_network_status 
        t_wifi_update=`date +%s`	
        if [[ $wifi_data -gt $MAX_WIFI || $docker_data -gt $MAX_DOCKER ]]
        then 
            myprint "Skipping net-testing since we are on wifi and data limit was passed ($wifi_data -> $MAX_WIFI) or ($docker_data -> $MAX_DOCKER)"
            skipping="true"
        fi
        if [[ $skipping == "false" ]]
        then
            myprint "./net-testing.sh in `check_network_status` $suffix $current_time $def_iface \"long\" > $output_path/net-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt"
            (./net-testing.sh $suffix $current_time $def_iface "long"| timeout 1200 cat > $output_path/net-testing-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 & )
            num=1
            echo $current_time > ".last_net"
        fi
	else
		myprint "Skipping net-testing. NetStatus:$net_status NumNetProc:$num DefIface:$def_iface LockedStatus:$locked network_type:$network_type"
	fi 
	
	# check if it is time to status report
	if [ -f ".last_report" ] 
	then 
		last_report_time=`cat ".last_report"`
	fi 
	let "time_from_last_report = current_time - last_report_time"
	myprint "Time from last report: $time_from_last_report sec"
	if [[ $testing == "true" ]] 
	then 
		myprint "Since testing, forcing time-from-last-report to 180000"
		time_from_last_report=18000
	fi 
	if [ $time_from_last_report -gt $REPORT_INTERVAL ] 
	then
		# make sure we have fresh wifi/mobile info		 
		update_network_status 
		t_wifi_update=`date +%s`	

		# update location info
		update_location

		# get uptime
		uptime_info=`get_uptime`

		if [[ $def_iface == "none" || $network_type != *"true"* ]] 
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
	if [[ $testing == "true" ]] 
	then
		myprint "One simple test was requested, interrupting!" 
		break
	fi 
done

# logging 
./stop-net-testing.sh
clean_file ".locked"
myprint "A request to interrupt $0 was received and executed. All good!"
