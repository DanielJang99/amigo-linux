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
	#sudo pm clear com.google.android.youtube
	sudo killall tcpdump
	close_all
	if [ $single != "true" ] 
	then
		turn_device_off
	fi 
}

send_report(){
	current_time=`date +%s`
	if [ $cpu_usage_middle == "N/A" ]
	then
		if [ -f ".cpu-usage" ] 
		then
			cpu_usage_middle=`cat .cpu-usage`
		fi
	fi 
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:8082/youtubetest
}

# activate stats for nerds  
activate_stats_nerds(){
	myprint "Activating stats for nerds!!"
	sudo input tap 680 105 && sleep 0.2 && sudo input tap 680 105
	sleep 3
	tap_screen 370 1022 3
	#tap_screen 370 1125 1 #3
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
    "cpu_util_midload_perc":"${cpu_usage_middle}",
    "avg_ping":"${avg_ping}",
    "bdw_used_MB":"${traffic}",
    "tshark_traffic_MB":"${tshark_size}", 
    "msg":"${msg}"
    }
EOF
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
cpu_usage_middle="N/A"

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


# measure ping to youtube 
ping -c 5 -W 2 youtube.com > notes-ping 2>&1
avg_ping=`cat notes-ping | grep "mdev" | cut -f 2 -d "=" | cut -f 2 -d "/"`
myprint "Average ping to youtube: $avg_ping"

# update UID if needed 
if [ $uid == "none" ]
then 
	uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
fi 
myprint "UID: $uid"

# folder creation
res_folder="./youtube-results/$suffix"
mkdir -p $res_folder
log_file="${res_folder}/${curr_run_id}-nerdstats.txt"

# cleanup the clipboard
termux-clipboard-set "none"

# make sure screen is ON
turn_device_on

# clean youtube cache
#sudo rm -rf /data/data/com.google.android.youtube/files /data/data/com.google.android.youtube/app_dg_cache /data/data/com.google.android.youtube/cache /data/data/com.google.android.youtube/no_backup /data/data/com.google.android.youtube/databases
myprint "Cleaning YT state"
base_folder="/data/data/com.google.android.youtube/"
sudo rm -rf "${base_folder}/app_dg_cache"
#/data/data/com.google.android.youtube/cache
sudo rm -rf "${base_folder}/cronet_metadata_cache"
sudo rm -rf "${base_folder}/image_manager_disk_cache"
sudo rm -rf "${base_folder}/volleyCache"
sudo rm -rf "${base_folder}/gms_cache"

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
    sudo tcpdump -i $interface -w $pcap_file > /dev/null 2>&1 &
	myprint "Started tcpdump: $pcap_file Interface: $interface"
fi

# get initial network data information
compute_bandwidth
traffic_rx=$curr_traffic
traffic_rx_last=$traffic_rx
# myprint "[INFO] Abs. Bandwidth: $traffic_rx"

#launch test video
am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=TSZxxqHoLzE"

#lower all the volumes
myprint "Making sure volume is off"
sudo media volume --stream 3 --set 0  # media volume
sudo media volume --stream 1 --set 0	 # ring volume
sudo media volume --stream 4 --set 0	 # alarm volume

# wait for GUI to load  -- FIXME 
sleep 10

# check stats for nerds
msg="NONE"
tap_screen 592 216 1
termux-clipboard-get > ".clipboard"
cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
if [ $? -ne 0 ] 
then
	activate_stats_nerds
	tap_screen 592 216 1
	termux-clipboard-get > ".clipboard"
	cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
	if [ $? -ne 0 ] 
	then
		msg="ERROR-STATS-NERDS"
	else
		cat ".clipboard" > $log_file
		echo "" >> $log_file
		myprint "Stats-for-nerds correctly detecting. Starting data collection for $DURATION seconds..."
	fi 
fi 

# collect data 
t_s=`date +%s`
t_e=`date +%s`
let "t_p = t_s - t_e"
let "HALF_DURATION = DURATION/2"
while [ $t_p -lt $DURATION ] 
do 
	# click to copy clipboard 
	tap_screen 592 216 1

	# dump clipboard 
	termux-clipboard-get >> $log_file
	echo "" >> $log_file

	# update on time passed 
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
tap_screen 670 1130 1 

# update traffic rx
compute_bandwidth $traffic_rx_last

# stop tcpdump 
if [ $pcap_collect == "true" ]
then
	my_ip=`ifconfig $interface | grep "\." | grep -v packets | awk '{print $2}'`
    sudo killall tcpdump
    myprint "Stopped tcpdump. Starting tshark analysis"
    tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
    tshark_size=`cat $tshark_file | awk -F "," -v my_ip=$my_ip '{if($4!=my_ip){if($8=="UDP"){tot_udp += ($NF-8);} if($8=="TCP"){tot_tcp += ($11);}}}END{tot=(tot_tcp+tot_udp)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000}'`
	gzip $tshark_file
	sudo rm $pcap_file
fi

# stop monitoring CPU
echo "false" > ".to_monitor"

# log and report 
if [ $msg == "NONE" ] 
then 
	msg="ALL-GOOD"
fi 
send_report
#if [ -f $log_file ]  # FIXME 
#then
#	data=`tail -n 1 $log_file`
#fi 

# clean youtube state and anything else 
safe_stop