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
	uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
	turn_device_on
	am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
	sleep 5 
	tap_screen 370 765 5
	tap_screen 370 765 5 
	tap_screen 370 660 2
	sudo input keyevent KEYCODE_BACK  
	close_all
	turn_device_off
	timeout 150 ./FTPClient $server_ip 8888 $uid 3G
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
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:8082/zeustest

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
	timeout 150 ./FTPClient $server_ip 8888 $uid 4G
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
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:8082/zeustest

	# status update 
	let "num_runs_today++"	
}

#logging 
echo "[`date`] net-testing START"

# params
MAX_RUNS=6
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
if [ $# -eq 3 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
fi  

# current free space 
free_space_s=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`

# run nyu stuff if mobile is available or if we really need samples 
sudo dumpsys netstats > .data
mobile_iface=`cat .data | grep "MOBILE" | grep "iface" | head -n 1  | cut -f 2 -d "=" | cut -f 1 -d " "`
if [ ! -z $mobile_iface ]
then 
	#  status update 
	curr_hour=`date +%H`
	status_file=".zus-${suffix}"
	num_runs_today=0
	if [ -f $status_file ]
	then
		num_runs_today=`cat $status_file`
	fi 	
	myprint "NYU-stuff. Found a mobile connection: $mobile_iface (DefaultConnection:$iface). NumRunsToday:$num_runs_today (MaxRuns: $MAX_RUNS)"
	if [ $iface == $mobile_iface -a $num_runs_today -lt $MAX_RUNS ] 
	then
		run_zus		
	#elif [ $curr_hour -ge 18 ] # we are past 6pm
	elif [ $curr_hour -ge 00 ] # we are past 6pm
	then 
		myprint "NYU-stuff. It is past 6pm and missing data. Resorting to disable WiFi"
		termux-wifi-enable false
		run_zus
		termux-wifi-enable true
		myprint "Enabling WiFi back"		
	else 
		myprint "NYU-stuff. Skipping since on WiFI and it not past 6pm"
	fi 
	echo $num_runs_today > $status_file
else 
	myprint "No mobile connection found. Skipping NYU-ZUS"
fi 

##################
exit -1 
##################

# run multiple MTR
./mtr.sh $suffix $t_s

# video testing with youtube -- SKIPPING, NOT RELIABLE
touch ".locked"
./youtube-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single
rm ".locked"
turn_device_off

# run a speedtest 
myprint "Running speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"
gzip "${res_folder}/speedtest-$t_s.json"


# allow some time to rest 
myprint "Resting post speedtest..."
sleep 30 

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s

# QUIC test? 
# TODO 

# test multiple webages
touch ".locked"
./web-test.sh  --suffix $suffix --id $t_s --iface $iface --pcap
rm ".locked"

# safety cleanup 
sudo pm clear com.android.chrome
#sudo pm clear com.google.android.youtube
close_all
sudo killall tcpdump
for pid in `ps aux | grep 'youtube-test\|web-test\|mtr.sh\|cdn-test.sh\|speedtest-cli'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do
    kill -9 $pid
done
turn_device_off

# current free space 
free_space_e=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
space_used=`echo "$free_space_s $free_space_e" | awk '{print($1-$2)*1000}'`

#logging 
echo "[`date`] net-testing END. FreeSpace: ${free_space_e}GB SpaceUsed: ${space_used}MB"