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
    uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
	if [ -f "uid-list.txt" ] 
	then 
		physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | cut -f 1`
	fi 
	myprint "UID: $uid PhysicalID: $physical_id"
	turn_device_on
	am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
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
MAX_ZEUS_RUNS=6             # maximum duration of NYU experiments
ZEUS_DURATION=20            # duration of NYU experiments
MAX_LOCATION=5              # timeout of duration command
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
opt="long"
if [ $# -eq 4 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
	opt=$4
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

# video testing with youtube
if [ $opt == "long" ] 
then 
	./v2/youtube-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single | timeout 300 cat
	turn_device_off
	myprint "Sleep 30 to lower CPU load..."
	sleep 30  		 
else 
	myprint "Skipping YouTube test sing option:$opt"
fi 

# run multiple MTR
./mtr.sh $suffix $t_s | timeout 300 cat 

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
# if [ ! -z $mobile_iface ]
# then 
# 	#  status update 
# 	curr_hour=`date +%H`
# 	status_file=".zus-${suffix}"
# 	if [ -f $status_file ]
# 	then
# 		num_runs_today=`cat $status_file`
# 	fi 	
# 	myprint "NYU-stuff. Found a mobile connection: $mobile_iface (DefaultConnection:$iface). NumRunsToday:$num_runs_today (MaxRuns: $MAX_ZEUS_RUNS)"
# 	if [ $iface == $mobile_iface -a $num_runs_today -lt $MAX_ZEUS_RUNS ] 
# 	then
# 		# make sure code is there (fix if not)
# 		if [ ! -f "FTPClient" ]
# 		then
# 			myprint "ERROR -- Missing FTPClient code, checking out!" 
# 			git checkout FTPClient
# 		fi 		
	
# 		##################### testing 
# 		myprint "Ensuring that screen is in portrait and auto-rotation disabled"
# 		sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
# 		sudo  settings put system user_rotation 0          # put in portrait
# 		##################### testing 
		
# 		run_zus		
# 		let "num_runs_today++"
# 		myprint "Done with zus. New count for the day: $num_runs_today"
# 		echo $num_runs_today > $status_file
# 		myprint "Sleep 30 to lower CPU load..."		
# 		sleep 30  		 
# 	else 
# 		myprint "NYU-stuff. Skipping since on WiFI!"
# 	fi 
# else 
# 	myprint "No mobile connection found. Skipping NYU-ZUS"
# fi 

# if on mobile, launch googlemaps which is now locked out on other process
# if [ ! -z $mobile_iface ]
# then 
# 	if [ $iface == $mobile_iface -a $num_runs_today -lt $MAX_ZEUS_RUNS ] 
# 	then 
# 		turn_device_on
# 		myprint "Launching googlemaps from net-testing since we are on mobile (and main process is holding back)"
# 		sudo monkey -p com.google.android.apps.maps 1 > /dev/null 2>&1
# 		sleep 15
# 		close_all
# 		turn_device_off
# 		res_dir="locationlogs/${suffix}"
# 		mkdir -p $res_dir		
# 		current_time=`date +%s`
# 		timeout $MAX_LOCATION termux-location -p network -r last > $res_dir"/network-loc-$current_time.txt"
# 		lat=`cat $res_dir"/network-loc-$current_time.txt" | grep "latitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`		
# 		long=`cat $res_dir"/network-loc-$current_time.txt" | grep "longitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`
# 		network_loc="$lat,$long"
# 		timeout $MAX_LOCATION termux-location -p gps -r last > $res_dir"/gps-loc-$current_time.txt"		
# 		lat=`cat $res_dir"/gps-loc-$current_time.txt" | grep "latitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`		
# 		long=`cat $res_dir"/gps-loc-$current_time.txt" | grep "longitude" | cut -f 2 -d ":" |sed s/","// | sed 's/^ *//g'`
# 		gps_loc="$lat,$long"		
# 		sudo dumpsys location > $res_dir"/loc-$current_time.txt"
# 		loc_str=`cat $res_dir"/loc-$current_time.txt" | grep "hAcc" | grep "passive" | head -n 1`
# 		gzip $res_dir"/loc-$current_time.txt"
# 		sleep 15 
# 	fi 
# fi

# run a speedtest 
myprint "Running speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
timeout 300 speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"
gzip "${res_folder}/speedtest-$t_s.json"
myprint "Sleep 30 to lower CPU load..."
sleep 30  		 

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s | timeout 300 cat
sleep 30 

# QUIC test? 
# TODO 

# test multiple webages -- TEMPORARILY DISABLED 
if [ $opt == "long" ] 
then 
	./v2/web-test.sh  --suffix $suffix --id $t_s --iface $iface --pcap --single | timeout 300 cat # reduced number of webpage tests
	sleep 30 
else 
	myprint "Skipping WebTest test sing option:$opt"
fi 

# safety cleanup 
sudo pm clear com.android.chrome
#sudo pm clear com.google.android.youtube
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