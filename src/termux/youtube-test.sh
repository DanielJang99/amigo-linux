#!/data/data/com.termux/files/usr/bin/bash
## NOTE: testing getting <<stats for nerds>> on youtube
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
	sudo pm clear com.google.android.youtube
	sudo killall tcpdump
	sudo input keyevent KEYCODE_HOME
}

# activate stats for nerds  
activate_stats_nerds(){
	myprint "Activating stats for nerds!!"
	tap_screen 680 105  3
	tap_screen 680 105  3
	tap_screen 370 1125 3
}

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load, --novideo, --disable, --uid"
    echo "================================================================================"
    echo "--load       Page load max duration"
    echo "--iface      Network interface in use"
    echo "--novideo    Turn off video recording"
	echo "--disable    Disable auto-play"
	echo "--pcap       Request pcap collection"	
	echo "--uid        IMEI of the device"
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
    "bdw_used_MB":"${traffic}",
    "tshark_traffic_MB":"${tshark_size}",
    "data:"${data}"
    }
EOF
}

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

# default parameters
DURATION=30                        # experiment duration
interface="wlan0"                  # default network interface to monitor (for traffic)
suffix=`date +%d-%m-%Y`            # folder id (one folder per day)
curr_run_id=`date +%s`             # unique id per run
disable_autoplay="false"           # flag to control usage of autoplay 
app="youtube"                      # used to detect process in CPU monitoring 
pcap_collect="false"               # flag to control pcap collection
uid="none"                         # user ID

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

# clean youtube state  
myprint "Cleaning YT state"
sudo pm clear com.google.android.youtube

# re-enable stats for nerds for the app
myprint "Launching YT and allow to settle..."
sudo monkey -p com.google.android.youtube 1 > /dev/null 2>&1 

# lower all the volumes
myprint "Making sure volume is off"
sudo media volume --stream 3 --set 0  # media volume
sudo media volume --stream 1 --set 0	 # ring volume
sudo media volume --stream 4 --set 0	 # alarm volume

# wait for YT 
myprint "Waiting for YT to load (aka detect \"WatchWhileActivity\")"
curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
while [ $curr_activity != "WatchWhileActivity" ] 
do 
	sleep 3 
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
	echo $curr_activity
done
sleep 3

# click account notification if there (guessing so far)
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

# potential issue when clicking a warning which is not there
if [ $need_to_verify -eq 1 ]
then 
	sudo input keyevent KEYCODE_BACK
	sleep 2 
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
	if [ $curr_activity != "WatchWhileActivity" ] 
	then 
		sudo monkey -p com.google.android.youtube 1 > /dev/null 2>&1 
		sleep 5 
	fi 
fi 
myprint "Enabling stats for nerds and no autoplay (in account settings)"
sudo input tap 665 100
sleep 3
sudo input tap 370 1180
sleep 3 
if [ $disable_autoplay == "true" ] 
then 
	sudo input tap 370 304
	sleep 3
	sudo input tap 370 230 
	sleep 3 
	sudo input keyevent KEYCODE_BACK
	sleep 3
fi 
sudo input tap 370 200
sleep 3
sudo input swipe 370 500 370 100
sleep 3 
sudo input tap 370 1250

# start CPU monitoring
log_cpu="${res_folder}/${curr_run_id}.cpu"
log_cpu_top="${res_folder}/${curr_run_id}.cpu_top"
clean_file $log_cpu
clean_file $log_cpu_top
myprint "Starting listener to CPU monitor. Log: $log_cpu"
echo "true" > ".to_monitor"
cpu_monitor $log_cpu &
#cpu_monitor_top $log_cpu_top &

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
sleep 5 # FIXME: normally not needed...

# make sure stats for nerds are active
myprint "Make sure stats for nerds are active"
ready="false"
attempt=0
while [ $ready == "false" ]
do 
	termux-clipboard-get > ".clipboard"
	cat ".clipboard" | grep "cplayer"
	if [ $? -ne 0 ] 
	then
		let "attempt++" 		
		activate_stats_nerds
		curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | awk -F "." '{print $NF}' | sed s/"}"//g`
		if [ $curr_activity != "WatchWhileActivity" ] 
		then
			myprint "Something went wrong!" 
			safe_stop			
		fi 
		tap_screen 592 216 1
		termux-clipboard-get > ".clipboard"
		cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
		if [ $? -eq 0 ] 
		then
			ready="true"		
			myprint "Ready to start!!"
			cat ".clipboard" > $log_file
			echo "" >> $log_file
		fi
		if [ $attempt -ge 2 ] 
		then 
			myprint "Something is WRONG. Clearing YT and exiting!"
			sudo pm clear com.google.android.youtube
			exit -1 
		fi 
	else
		ready="true"		
		echo "Ready to start!!"
	fi
done

# collect data 
myprint "Stats-for-nerds correctly detecting. Starting data collection for $DURATION seconds..."
t_s=`date +%s`
t_e=`date +%s`
let "t_p = t_s - t_e"
cpu_usage_middle="N/A"
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
	if [ $t_p -le $HALF_DURATION] 
	then 
		if [ -f ".cpu-usage" ]
    	then 
        	cpu_usage_middle=`cat .cpu-usage`
    	fi
    fi 
done

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
	myprint "$tshark_size"
    sudo rm $pcap_file
fi

# stop monitoring CPU
echo "false" > ".to_monitor"

# log and report 
current_time=`date +%s`
myprint "Sending report to the server: "
if [ -f $log_file ] 
then
	data=`tail -n 1 $log_file`
	current_time=`date +%s`
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 
	timeout 10 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)"  https://mobile.batterylab.dev:8082/youtubetest
fi 

# clean youtube state and anything else 
safe_stop