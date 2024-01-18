#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 12/14/2023

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	safe_stop
	exit -1 
}

safe_stop(){
	myprint "Entering safe stop..."
	sudo  settings put system user_rotation 0 
	sudo killall tcpdump
	turn_device_on
	close_all
	if [ $single != "true" ] 
	then
		turn_device_off
	fi 
}

send_report(){
	current_time=`date +%s`
	avg_ping="N/A"
	if [ -f "notes-ping" ] 
	then 
		myprint "---------ping stats---------"
		tail -n 2 notes-ping
		avg_ping=`cat notes-ping | grep "mdev" | cut -f 2 -d "=" | cut -f 2 -d "/"`
		myprint "Average ping to youtube: $avg_ping"
		rm notes-ping 
	fi
	if [ -f "notes-nping" ]
	then
		myprint "---------nping stats---------" 
		tail -n 3 notes-nping | head -n 2 
		avg_nping=`cat notes-nping | grep "Avg rtt" | cut -f 4 -d ":" | cut -f 1 -d "m" | cut -f 2 -d " "`
		myprint "Average nping to youtube: $avg_nping"
		rm notes-nping
	fi
	if [ -f "notes-ping6" ] 
	then 
		avg_ping6=`cat notes-ping6 | grep "mdev" | cut -f 2 -d "=" | cut -f 2 -d "/"`
		myprint "Average ping6 to youtube: $avg_ping6"
		rm notes-ping6
	fi 

	if [ $cpu_usage_middle == "N/A" ]
	then
		if [ -f ".cpu-usage" ] 
		then
			cpu_usage_middle=`cat .cpu-usage`
		fi
	fi 
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:$SERVER_PORT/youtubetest
}


# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load, --novideo, --disable, --uid, --pcap, --single, --dur"
    echo "================================================================================"
    echo "--iface      Network interface in use"
    echo "--novideo    Turn off video recording"
	echo "--disable    Disable auto-play"
	echo "--pcap       Request pcap collection"	
	echo "--uid        IMEI of the device"
	echo "--single     User test, make it easier"
    echo "--dur        How long to run (seconds)"    
    echo "================================================================================"
    exit -1
}

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "test_id":"${curr_run_id}",
    "cpu_util_midload_perc":"${cpu_usage_middle}",
    "avg_ping":"${avg_ping}",
    "avg_nping":"${avg_nping}",
    "avg_ping6":"${avg_ping6}",    
    "bdw_used_MB":"${traffic}",
    "tshark_traffic_MB":"${tshark_size}", 
    "msg":"${msg}", 
	"network_type": "${network_type}"
    }
EOF
}

# helper to ping youtube 
ping_youtube(){
	ping -c 5 -W 2 youtube.com > notes-ping 2>&1
	nping -c 5 youtube.com > notes-nping 2>&1
	ping6 -c 5 -W 2 youtube.com > notes-ping6 2>&1
}

# wait for sane CPU values ss
wait_on_cpu(){
	if [ -f ".cpu-usage" ]
	then 
		sleep 5
		t1=`date +%s`
		t2=`date +%s`
		let "tp = t2 - t1"
		cpu_val=`cat .cpu-usage | cut -f 1 -d "."`
		myprint "CPU: $cpu_val"	    
		while [ $tp -lt $MAX_LAUNCH_TIMEOUT -a $cpu_val -gt 95 ]
		do 
		    cpu_val=`cat .cpu-usage | cut -f 1 -d "."`
		    myprint "CPU: $cpu_val"
		    sleep 2
		    t2=`date +%s`
			let "tp = t2 - t1"
		done
	else 
		sleep 10 
	fi 
}


# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

# default parameters
# DURATION=60                        # experiment duration
DURATION=20                        # experiment duration
interface="wlan0"                  # default network interface to monitor (for traffic)
suffix=`date +%d-%m-%Y`            # folder id (one folder per day)
curr_run_id=`date +%s`             # unique id per run
disable_autoplay="false"           # flag to control usage of autoplay 
app="youtube"                      # used to detect process in CPU monitoring 
pcap_collect="false"               # flag to control pcap collection
uid="none"                         # user ID
single="false"                     # user initiated test (same logic as per web)
sleep_time=5                       # time to sleep between clicks
first_run="false"                  # first time ever youtube was run
cpu_usage_middle="N/A"             # CPU measured in the middle of a test 
MAX_LAUNCH_TIMEOUT=30              # maximum duration for youtube to launch
record_video="false"               # record a video of enabling stats for nerds 
network_type=`get_network_type`

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        --dur)
            shift; DURATION="$1"; shift;
            ;;
        --iface)
            shift; interface="$1"; shift;
            ;;
        --suffix)
            shift; suffix="$1"; shift;
            ;;
        --id)
            shift; curr_run_id="$1"; shift;
            ;;
		--disable)
            shift; disable_autoplay="true"; 
            ;;
		 --pcap)
            shift; pcap_collect="true";
            ;;
        --uid)
        	shift; uid="$1"; shift;
            ;;
        --single)
            shift; single="true"; 
            ;;
        --dur)
			shift; DURATION="$1"; shift; 
            ;;
        --record)
			shift; record_video="true"; 
			;;        
        -h | --help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# indicate current network in curr_run_id
network_ind=`echo $network_type | cut -f 1 -d "_"`
curr_run_id="${curr_run_id}_${network_ind}"

# retrieve last used server port 
if [ -f ".server_port" ] 
then 
	SERVER_PORT=`cat ".server_port"`
else 
	SERVER_PORT="8082"
fi 

# make sure only this instance of this script is running 
my_pid=$$ 
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

# measure ping to youtube  (should be safe in background)
ping_youtube &

# update UID if needed 
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

# folder creation
res_folder="./youtube-results/$suffix"
mkdir -p $res_folder

# make sure screen is ON
turn_device_on

# clean kiwi cache 
myprint "Cleaning YT cache"
su -c rm -fr /data/data/com.kiwibrowser.browser/cache/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_tabs/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_persisted_tab_data_storage/*

# start CPU monitoring
log_cpu="${res_folder}/${curr_run_id}.cpu"
clean_file $log_cpu
myprint "Starting listener to CPU monitor. Log: $log_cpu"
echo "true" > ".to_monitor"
cpu_monitor $log_cpu &

# start pcap collection if needed
if [ $pcap_collect == "true" ]
then
    pcap_file="${res_folder}/${curr_run_id}.pcap"
    tshark_file="${res_folder}/${curr_run_id}.tshark"
    #sudo tcpdump -i $interface -w $pcap_file > /dev/null 2>&1 &
	#sudo tcpdump -i $interface -vv ip6 -w $pcap_file > /dev/null 2>&1 &
	sudo tcpdump -i $interface ip6 or ip -w $pcap_file > /dev/null 2>&1 &
	myprint "Started tcpdump: $pcap_file Interface: $interface"
fi

# make sure screen is in landscape 
myprint "Ensuring that screen is in landscape and auto-rotation disabled"
sudo settings put system accelerometer_rotation 0 # disable (shows portrait) 
sudo settings put system user_rotation 1          # put in landscape

#launch test video
su -c am start -n com.kiwibrowser.browser/com.google.android.apps.chrome.Main -d https://www.youtube.com/watch?v=TSZxxqHoLzE

#lower all the volumes
myprint "Making sure volume is off"
termux-volume call 0                     # call volume 
termux-volume music 0
termux-volume system 0


# get initial network data information
compute_bandwidth
traffic_rx=$curr_traffic
traffic_rx_last=$traffic_rx

# wait for GUI to load
wait_on_cpu

############# testing 
if [ $record_video == "true" ]
then 
	screen_video="${res_folder}/screen-${curr_run_id}.mp4"
	(sudo screenrecord $screen_video --time-limit 10 &) #--bit-rate 1000000
	myprint "Started screen recording on file: $screen_video"
fi 
#####################

# update youtube settings 
(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no ${screen_file}".webp" root@23.235.205.53:$remote_file > /dev/null 2>&1 &)

# video collection if requested
if [ $record_video == "true" ]
then 
	sudo chown $USER:$USER $screen_video
	remote_file="/root/mobile-testbed/src/server/youtube/${uid}-${curr_run_id}.mp4"	
	(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no ${screen_video} root@23.235.205.53:$remote_file > /dev/null 2>&1 &)
fi 

# start playing video 
sleep 3 
sudo input tap 1300 500

# collect data 
myprint "Starting data collection for $DURATION seconds..."
t_s=`date +%s`
t_e=`date +%s`
let "t_p = t_s - t_e"
let "HALF_DURATION = DURATION/2"
attempt=1
msg="ALL-GOOD"
while [ $t_p -lt $DURATION ] 
do 
    sleep 1;
	# make sure we are still inside the app
	curr_activity=`sudo dumpsys activity | grep -E 'mCurrentFocus' | tail -n 1`
    if [[ $curr_activity != *"com.kiwibrowser.browser"* ]] 
    then 
    	msg="ERROR-LEFT-KIWI"
    	myprint "ERROR detected. We left KIWI!"
    	break 
    fi 
	# rate control 
	sleep 1 
	t_e=`date +%s`
	let "t_p = t_e - t_s"

	# keep track of CPU in the middle
	if [ $t_p -le $HALF_DURATION ] 
	then 
		if [ -f ".cpu-usage" ]
    	then 
        	cpu_usage_middle=`cat .cpu-usage`
    	fi
    fi 
done

# stop playing (attempt)
# myprint "Stop playing!"
# sudo input keyevent KEYCODE_BACK
# sleep 2 
# sudo input tap 565 400
# sudo input tap 565 400

# stop tcpdump 
if [ $pcap_collect == "true" ]
then
	my_ip=`sudo ifconfig $interface | grep "\." | grep -v packets | awk '{print $2}'`
    sudo killall tcpdump
    myprint "Stopped tcpdump. Starting tshark analysis"
    tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
    tshark_size=`cat $tshark_file | awk -F "," '{if($8=="UDP"){tot_udp += ($NF-8);} else if(index($8,"QUIC")!=0){tot_quic += ($NF-8);} else if($8=="TCP"){tot_tcp += ($11);}}END{tot=(tot_tcp+tot_udp+tot_quic)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000 " TOT-QUIC:" tot_quic/1000000}'`
    myprint "[INFO] Traffic received (according to tshark): $tshark_size"
	gzip $tshark_file
	sudo rm $pcap_file
fi

# stop monitoring CPU
echo "false" > ".to_monitor"

# clean youtube state and anything else 
safe_stop

# kill youtube process if present 
youtube_pid=`sudo ps aux | grep "com.kiwibrowser" | grep -v "grep" | grep -v "browser_" | grep -v "browser:" | awk '{print $2}'`
if [ ! -z $youtube_pid ]
then 
	sudo kill -9 $youtube_pid
fi

# update traffic received counter 
compute_bandwidth $traffic_rx_last
myprint "[INFO] Traffic received (according to interface): $traffic"

# send report 
send_report
su -c rm -fr /data/data/com.kiwibrowser.browser/cache/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_tabs/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_persisted_tab_data_storage/*
#if [ -f $log_file ]  # FIXME 
#then
#	data=`tail -n 1 $log_file`
#fi 