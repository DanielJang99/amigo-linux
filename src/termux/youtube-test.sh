#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: 1) get <<stats for nerds>> on youtube ; 2) manage Google account
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

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
		avg_ping=`cat notes-ping | grep "mdev" | cut -f 2 -d "=" | cut -f 2 -d "/"`
		myprint "Average ping to youtube: $avg_ping"
		rm notes-ping 
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

# activate stats for nerds  
activate_stats_nerds(){
	myprint "Activating stats for nerds!!"
	#sudo input tap 1240 50 && sleep 0.5 && sudo input tap 1240 50
	sudo input tap 1240 50
	sudo input tap 1240 50	
	sleep 1.5
	tap_screen 670 670 1
	#tap_screen 670 670 3
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
    "avg_ping6":"${avg_ping6}",    
    "bdw_used_MB":"${traffic}",
    "tshark_traffic_MB":"${tshark_size}", 
    "msg":"${msg}"
    }
EOF
}

# helper to ping youtube 
ping_youtube(){
	ping -c 5 -W 2 youtube.com > notes-ping 2>&1
	ping6 -c 5 -W 2 youtube.com > notes-ping6 2>&1

}

# wait for sane CPU values 
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
DURATION=60                        # experiment duration
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
        -h | --help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

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
if [ $uid == "none" ]
then 
	uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
fi 
if [ -f "uid-list.txt" ] 
then 
	physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | cut -f 1`
fi 
myprint "UID: $uid PhysicalID: $physical_id"

# folder creation
res_folder="./youtube-results/$suffix"
mkdir -p $res_folder
log_file="${res_folder}/${curr_run_id}-nerdstats.txt"

# cleanup the clipboard
termux-clipboard-set "none"

# make sure screen is ON
turn_device_on

# clean youtube cache 
myprint "Cleaning YT cache"
base_folder="/data/data/com.google.android.youtube/"
sudo mv $base_folder/ ./
sudo pm clear com.google.android.youtube
sudo mv com.google.android.youtube/ "/data/data/"

# launch YouTube and wait for sane CPU values 
#myprint "Launching YT and wait for sane CPU"
#sudo monkey -p com.google.android.youtube 1 > /dev/null 2>&1 
#wait_on_cpu

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
sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
sudo  settings put system user_rotation 1          # put in landscape

#launch test video
am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=TSZxxqHoLzE"

#lower all the volumes
myprint "Making sure volume is off"
termux-volume call 0                     # call volume 
sudo media volume --stream 3 --set 0     # media volume
sudo media volume --stream 1 --set 0	 # ring volume
sudo media volume --stream 4 --set 0	 # alarm volume

# get initial network data information
compute_bandwidth
traffic_rx=$curr_traffic
traffic_rx_last=$traffic_rx

# wait for GUI to load
wait_on_cpu

# activate stats for nerds
msg="NONE"
activate_stats_nerds

# take a screenshot to see what is on screen and send to the server (in case of failure)
screen_file="${res_folder}/screen-${curr_run_id}"
sudo screencap -p $screen_file".png"
sudo chown $USER:$USER $screen_file".png"
cwebp -q 80 ${screen_file}".png" -o ${screen_file}".webp" > /dev/null 2>&1 
if [ -f ${screen_file}".webp" ]
then 
	chmod 644 ${screen_file}".webp"
	rm ${screen_file}".png"
fi

# attempt grabbing stats for nerds
tap_screen 1160 160 1
termux-clipboard-get > ".clipboard"
cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
if [ $? -ne 0 ] 
then
	msg="ERROR-STATS-NERDS"
	myprint "Stats-for-nerds issue"
	ready="false"
	remote_file="/root/mobile-testbed/src/server/youtube/${id}-${curr_run_id}.webp" 	
	(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no ${screen_file}".webp" root@23.235.205.53:$remote_file > /dev/null 2>&1 &)
else
	cat ".clipboard" > $log_file
	echo "" >> $log_file
	myprint "Stats-for-nerds correctly detecting"
	ready="true"
fi 

# collect data 
myprint "Starting data collection for $DURATION seconds..."
t_s=`date +%s`
t_e=`date +%s`
let "t_p = t_s - t_e"
let "HALF_DURATION = DURATION/2"
attempt=1
while [ $t_p -lt $DURATION ] 
do 
	if [ $ready == "true" ]
	then 
		# click to copy clipboard 
		tap_screen 1160 160 1
		termux-clipboard-get >> $log_file 
		echo "" >> $log_file	
		msg="ALL-GOOD"
	else 
		if [ $attempt -le 3 ] 
		then
			myprint "Stats-for-nerds not found...retrying! ($attempt/3)"
			msg="ERROR-STATS-NERDS"			
			activate_stats_nerds
			let "attempt++"
			tap_screen 1160 160 1  # click to copy clipboard 
			termux-clipboard-get > ".clipboard"
			cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
			if [ $? -eq 0 ]
			then
				ready="true" 
			fi 
		fi 
	fi 

	# make sure we are still inside the app
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
    if [ $curr_activity != "WatchWhileActivity" ] 
    then 
    	msg="ERROR-LEFT-YOUTUBE"
    	myprint "ERROR detected. We left YouTube!"
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
gzip $log_file

# stop playing (attempt)
myprint "Stop playing!"
sudo input keyevent KEYCODE_BACK
sleep 2 
tap_screen 1000 580

# stop tcpdump 
if [ $pcap_collect == "true" ]
then
	my_ip=`ifconfig $interface | grep "\." | grep -v packets | awk '{print $2}'`
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

# update traffic received counter 
compute_bandwidth $traffic_rx_last
myprint "[INFO] Traffic received (according to interface): $traffic"

# send report 
send_report
#if [ -f $log_file ]  # FIXME 
#then
#	data=`tail -n 1 $log_file`
#fi 