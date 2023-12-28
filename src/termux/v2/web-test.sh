#!/data/data/com.termux/files/usr/bin/env bash
## Author: Matteo Varvello 
## Date:   11/10/2021

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	safe_stop
}

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file 

# safe run interruption
safe_stop(){	
	turn_device_on
    close_all
    turn_device_off
    myprint "[safe_stop] EXIT!"
    exit 0
}

#helper to  load utilities files
load_file(){
    if [ -f $1 ]
    then
        source $1
    else
        echo "Utility file $1 is missing"
        exit -1
    fi
}

# take final screenshot + scrolling 
take_screenshots(){
	if [ -f ".done-screenshots" ]
	then 
		rm ".done-screenshots"
	fi 
	counter=1
	while [ $counter -lt 5 ]
	do 
		sudo input swipe 300 1000 300 300
		sleep 2 
		screen_file="${res_folder}/${id}-${curr_run_id}-${counter}"
		sudo screencap -p $screen_file".png"
		sudo chown $USER:$USER $screen_file".png"
		cwebp -q 80 ${screen_file}".png" -o ${screen_file}".webp" > /dev/null 2>&1 
		if [ -f ${screen_file}".webp" ]
		then 
			chmod 644 ${screen_file}".webp"
			sudo rm ${screen_file}".png"
		fi 
		let "counter++"
	done	 
	touch ".done-screenshots"
}

# run video ananlysis for web perf
visual(){
	rm ".visualmetrics"
    sleep 5 # allow things to finish (maybe can be saved)
    myprint "Running visualmetrics/visualmetrics.py (background - while visual prep is done)"
	sudo chmod +r $screen_video
	python /data/data/com.termux/files/home/mobile-testbed/src/setup/visualmetrics/visualmetrics.py --video $screen_video --viewport > $perf_video 2>&1
	speed_index=`cat $perf_video | grep "Speed Index" | head -n 1 | cut -f 2 -d ":" | sed s/" "//g`
	last_change=`cat $perf_video | grep "Last Visual Change"| head -n 1 | cut -f 2 -d ":" | sed s/" "//g`
	echo -e "$speed_index\t$last_change" > ".visualmetrics"
	gzip $perf_video
	sudo rm $screen_video
}

# helper to extra last frame of a video
# setup browser for next experiment
browser_setup(){
	myprint "Disabling welcome tour. NOTE: this only works in Chrome unfortunately"
	sudo sh -c "echo '${app} --disable-fre --no-default-browser-check --no-first-run --disable-notifications --disable-popup-blocking --enable-automation --disable-background-networking' > /data/local/tmp/chrome-command-line"
	#am set-debug-app --persistent $package $NOT WORKING
}

# run a test and collect data 
run_test(){
	# params 
	MAX_DURATION=30 	
	
	# get initial network data information
    compute_bandwidth
    traffic_rx=$curr_traffic
    traffic_rx_last=$traffic_rx
    # myprint "[INFO] Abs. Bandwidth: $traffic_rx"

	# attempt page load 
	myprint "URL: $url PROTO: $PROTO  RES-FOLDER: $res_folder TIMEOUT: $MAX_DURATION"
	t_launch=`date +%s`
	#am start -n $package/$activity -a $intent -d $url 
	su -c am start -n $package/$activity -d $url 	
	t_now=`date +%s`

	# manage screen recording
	if [ $video_recording == "true" ]
	then
    	t=`date +%s`
    	screen_video="${res_folder}/${id}-${curr_run_id}.mp4"
    	perf_video="${res_folder}/${id}-${curr_run_id}.perf"
	    (sudo screenrecord $screen_video --time-limit $load_time &) #--bit-rate 1000000
		myprint "Started screen recording on file: $screen_video"
	fi

	# artificial time for page loading
	cpu_usage_middle="N/A"
	let "half = load_time/2"
	sleep $half
	if [ -f ".cpu-usage" ]
    then 
        cpu_usage_middle=`cat .cpu-usage`
    fi  
	if [ $url == "https://www.nytimes.com/" ]
	then 
		myprint "Attempt accepting cookies"
		tap_screen 120 1200
	elif [ $url == "https://www.wsj.com/" ]
	then 
		myprint "Block WSJ notifications"
		tap_screen 630 1330  
	fi 
	sleep $half

	# stop video recording and run we perf analysis
	if [ $video_recording == "true" ]
	then
		sudo chown $USER:$USER $screen_video
		if [ -f "visualmetrics/visualmetrics.py" ] 
		then
			myprint "Running visual analysis in the background" 
			visual &
		else 
			myprint "Visualmetrics not found"
		fi 
	fi	

	# update traffic rx (for this URL)
	compute_bandwidth $traffic_rx_last
	traffic_rx_last=$curr_traffic
	traffic_before_scroll=$traffic
	
	# prepare info to log results 
	energy="N/A"
	t_now=`date +%s`
	let "duration = t_now - t_launch"

	# update traffic rx (for this URL, after scroll)
	compute_bandwidth $traffic_rx_last
	traffic_rx_last=$curr_traffic
	traffic_after_scroll=$traffic	
}

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "cpu_util_midload_perc":"${cpu_usage_middle}",
    "browser":"${browser}",
    "URL":"${url}",
    "bdw_load_MB":"${traffic_before_scroll}",
    "bdw_scroll_MB":"${traffic_after_scroll}",
    "tshark_traffic_MB":"${tshark_size}",
    "load_dur_sec":"${load_time}",
    "speed_index_ms":"${speed_index}",
    "last_visual_change_ms":"${last_change}",
	"network_type": "${network_type}"
    }
EOF
}

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load,	--novideo, --single, --url, --pcap, --uid"
    echo "================================================================================"
    echo "--load       Page load max duration"
    echo "--iface      Network interface in use"
    echo "--novideo    Turn off video recording" 
    echo "--single     Just one test" 
    echo "--url        Force using a passed URL"       
    echo "--pcap       Collect pcap traces"
    echo "--uid        IMEI of the device"
    echo "================================================================================"
    exit -1
}

# parameters 
monitor="false"                    # Control if to monitor cpu/bandwdith or not
url="www.google.com"               # default URL to test 
load_time=30                       # default load time 
video_recording="true"             # record screen or not
interface="wlan0"                  # default network interface to monitor (for traffic)
suffix=`date +%d-%m-%Y`            # folder id (one folder per day)
curr_run_id=`date +%s`             # unique id per run
single="false"                     # should run just one test 
pcap_collect="false"               # flag to control pcap collection at the phone
app="chrome"                       # used to detect process in CPU monitoring
url="none"                         # URL to test 
uid="none"                         # user ID
network_type=`get_network_type`	

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        --load)
            shift; load_time="$1"; shift;
            ;;
        --novideo)
            shift; video_recording="false";
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
        --single)
            shift; single="true"; 
            ;;
        --url)
        	shift; url="$1"; single="true"; shift;
            ;;
        --uid)
        	shift; uid="$1"; shift;
            ;;
        --pcap)
            shift; pcap_collect="true";
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

# retrieve last used server port 
if [ -f ".server_port" ] 
then 
	SERVER_PORT=`cat ".server_port"`
else 
	SERVER_PORT="8082"
fi 

myprint "Ensuring that screen is in portrait and auto-rotation disabled"
sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
sudo  settings put system user_rotation 0          # put in portrait

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
myprint "UID: $uid PhisicalID: $physical_id"

# folder creation
res_folder="./website-testing-results/$suffix"
mkdir -p $res_folder

# make sure the screen is ON
turn_device_on

# load urls to be tested
url_file="urls_list.txt"
num_urls=0
while read line
do 
    urlList[$num_urls]="$line"
    let "num_urls++"
done < $url_file

# clean the browser before testing 
browser="kiwi"
package="com.kiwibrowser.browser"
activity="com.google.android.apps.chrome.Main"
myprint "[INFO] Cleaning browser data ($app-->$package)"
cur_app=`sudo dumpsys activity | grep -E 'mCurrentFocus' | grep -E $package`
iter=0
while [ -z "$cur_app" ]
do
	turn_device_on
	su -c rm -fr /data/data/com.kiwibrowser.browser/cache/*
	su -c rm -fr /data/data/com.kiwibrowser.browser/app_tabs/*
	su -c rm -fr /data/data/com.kiwibrowser.browser/app_persisted_tab_data_storage/*
	sleep 3
	su -c am start -n $package/$activity
	sleep 4
	cur_app=`sudo dumpsys activity | grep -E 'mCurrentFocus' | grep -E $package`
	let "iter++"

	if [ $iter -eq 10 ];then
		myprint "[ERROR] Chrome failed to open after 10 tries..."
		exit 1
	fi

done
#chrome_onboarding
#myprint "[INFO] Chrome Onboarding Complete"
#browser_setup #FIXME => allow to skip chrome onboarding, but using a non working option

# get private  IP in use
my_ip=`sudo ifconfig $interface | grep "\." | grep -v "packets" | awk '{print $2}'`
myprint "Interface: $interface IP: $my_ip" 

# loop across URLs to be tested
myprint "Loaded $num_urls URLs"
screenshots_flag="false"
for((ii=0; ii<num_urls; ii++))
do
    # get URL to be tested 
    if [ $url == "none" ] 
   	then
		if [ $single == "true" ] 
		then 
			let "i = RANDOM % num_urls"
		    url=${urlList[$i]} 
		    myprint "Random URL: $url ($i)"
			ii=$num_urls
		else 
		    url=${urlList[$ii]} 
		    myprint "Next URL: $url ($i)"
	 	fi 
	else 
	 	myprint "Using URL passed by user: $url"
		ii=$num_urls	
	fi 
	
    # file naming
    id=`echo $url | md5sum | cut -f1 -d " "`
    log_cpu="${res_folder}/${id}-${curr_run_id}.cpu"
    log_cpu_top="${res_folder}/${id}-${curr_run_id}.cpu_top"
    log_traffic="${res_folder}/${id}-${curr_run_id}.traffic"
    log_run="${res_folder}/${id}-${curr_run_id}.run"
    
    # start background process to monitor CPU on the device
    clean_file $log_cpu
    clean_file $log_cpu_top
    myprint "Starting listener to CPU monitor. Log: $log_cpu"
    echo "true" > ".to_monitor"
    cpu_monitor $log_cpu &
	#cpu_monitor_top $log_cpu_top &

	# start pcap collection if needed
	if [ $pcap_collect == "true" ]
	then
		pcap_file="${res_folder}/${id}-${curr_run_id}.pcap"
		tshark_file="${res_folder}/${id}-${curr_run_id}.tshark"
		#sudo tcpdump -i $interface -w $pcap_file > /dev/null 2>&1 &
		sudo tcpdump -i $interface ip6 or ip -w $pcap_file > /dev/null 2>&1 &	
		myprint "Started tcpdump: $pcap_file Interface: $interface"
	fi
    
    # run a test 
    run_test 
    
	# stop monitoring CPU
	myprint "Stop monitoring CPU"
	echo "false" > ".to_monitor"
	t_1=`date +%s`

	# take screenshot of final load
	counter=0
	screen_file="${res_folder}/${id}-${curr_run_id}-${counter}"
	sudo screencap -p $screen_file".png"
	sudo chown $USER:$USER $screen_file".png"
	cwebp -q 80 ${screen_file}".png" -o ${screen_file}".webp" > /dev/null 2>&1 
	if [ -f ${screen_file}".webp" ]
	then 
		chmod 644 ${screen_file}".webp"
		sudo rm ${screen_file}".png"
	fi 
	t_last_scroll=0
	if [ -f ".time_last_scroll" ] 
	then
		t_last_scroll=`cat ".time_last_scroll"`
	fi
	let "time_passed = t_1 - t_last_scroll"
	if [ $time_passed -ge 3600 ] # only take one per hour, to save space 
	then
		take_screenshots &
		screenshots_flag="true"		 
	else 
		touch ".done-screenshots"
	fi 

   	# stop pcap collection and run analysis 
	tshark_size="N/A"
	if [ $pcap_collect == "true" ]
	then
		sudo killall tcpdump	
		myprint "Stopped tcpdump. Starting background analysis: $pcap_file"
		tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
		#tshark_size=`cat $tshark_file | awk -F "," -v my_ip=$my_ip '{if($4!=my_ip){if($8=="UDP"){tot_udp += ($NF-8);} if($8=="TCP"){tot_tcp += ($11);}}}END{tot=(tot_tcp+tot_udp)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000}'`
		tshark_size=`cat $tshark_file | awk -F "," '{if($8=="UDP"){tot_udp += ($NF-8);} else if(index($8,"QUIC")!=0){tot_quic += ($NF-8);} else if($8=="TCP"){tot_tcp += ($11);}}END{tot=(tot_tcp+tot_udp+tot_quic)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000 " TOT-QUIC:" tot_quic/1000000}'`
		sudo rm $pcap_file
		gzip $tshark_file
	fi
	myprint "Done with tshark analysis"
	
	# wait for screenshotting to be done
	while [ ! -f ".done-screenshots" ]
	do 
		sleep 2
		#myprint "Waiting for scrolling + screenshotting to be done!"
	done
	rm ".done-screenshots"

	# # make sure CPU background process is done
	# t_2=`date +%s`
	# let "t_sleep = 5 - (t_2 - t_1)"
	# if [ $t_sleep -gt 0  -a $single != "true" ] 
	# then 
	# 	echo "Sleeping: $t_sleep"
	# 	sleep $t_sleep
	# fi 
	
	# # make sure visual analysis is done 
	# myprint "Waiting for visual metrics - START"
	# ps aux | grep "visualmetrics.py" | grep -v "grep"
	# ans=$?
	# while [ $ans -eq 0 ]
	# do 
	# 	sleep 2
	# 	ps aux | grep "visualmetrics.py" | grep -v "grep"
	# 	ans=$?
	# 	let "c++"
	# 	if [ $c -ge 10 ]
	# 	then
	# 		# stop process 						 
	# 		myprint "visualmetrics.py seems stuck. Killing it."
	# 		for pid in `ps aux | grep "visualmetrics.py" | grep -v "grep" | awk '{print $2}'`
	# 		do 
	# 			kill -9 $pid
	# 		done			
	# 		break 
	# 	fi 
	# done
	myprint "Waiting for visual metrics to be done..."
	c=0
	while [ ! -f ".visualmetrics" ] 
	do 
		sleep 2 
		let "c++"
		if [ $c -eq 15 ]
		then 
			# stop process 						 
			myprint "visualmetrics.py seems stuck. Killing it."
			for pid in `ps aux | grep "visualmetrics.py" | grep -v "grep" | awk '{print $2}'`
			do 
				kill -9 $pid
			done
			break 
		fi 
	done
	if [ -f ".visualmetrics" ] 
	then
		speed_index=`cat ".visualmetrics" | cut -f 1`
		last_change=`cat ".visualmetrics" | cut -f 2`
	fi 

	# log and report 
	current_time=`date +%s`
	myprint "Sending report to the server: "
	echo "$(generate_post_data)" 	
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/webtest
	myprint "[RESULTS]\tBrowser:$browser\tURL:$url\tBDW-LOAD:$traffic_before_scroll MB\tBDW-SCROLL:$traffic_after_scroll MB\tTSharkTraffic:$tshark_size\tLoadTime:$load_time\tSpeedIndex:$speed_index\tLastVisualChange:$last_change"

	# rest url
	url="none"   	
done

# keep track of time when screenshots were taken
if [ $screenshots_flag == "true" ]
then
	echo `date +%s` > ".time_last_scroll"
fi

# all done
safe_stop
su -c rm -fr /data/data/com.kiwibrowser.browser/cache/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_tabs/*
su -c rm -fr /data/data/com.kiwibrowser.browser/app_persisted_tab_data_storage/*

# kill kiwi process if present 
kiwi_pid=`sudo ps aux | grep "com.kiwibrowser.browser" | grep -v "grep" | grep -v "browser_" | grep -v "browser:" | awk '{print $2}'`
if [ ! -z $kiwi_pid ]
then 
	sudo kill -9 $kiwi_pid
fi