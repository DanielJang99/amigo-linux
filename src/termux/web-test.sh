#!/data/data/com.termux/files/usr/bin/bash
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
    # go HOME and close all 
    close_all

    # turn screen off 
    turn_device_off
   
    # all done
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
		screen_file="${res_folder}/${id}-${curr_run_id}-${counter}.png"
		sudo screencap -p $screen_file
		sudo chown $USER:$USER $screen_file		
		let "counter++"
	done	 
	touch ".done-screenshots"
}

# run video ananlysis for web perf
visual(){
	myprint "Running visualmetrics/visualmetrics.py (background - while visual prep is done)"
	python visualmetrics/visualmetrics.py --video $screen_video --viewport > $perf_video 2>&1
	ans=`cat $perf_video | grep "Speed Index"`
	ans_more=`cat $perf_video | grep "Last"`
	myprint "VisualMetric - $perf_video - $ans $ans_more"
	rm $screen_video
	#(python visualmetrics/visualmetrics.py --video $final_screen_video --dir frames -q 75 --histogram histograms.json.gz --orange --viewport > $perf_video 2>&1 &)
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
	am start -n $package/$activity -a $intent -d $url 
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
	sleep $load_time 

	# stop video recording and run we perf analysis
	if [ $video_recording == "true" ]
	then
		sleep 5 # allow things to finish (maybe can be saved)
		sudo chown $USER:$USER $screen_video
		if [ -f "visualmetrics/visualmetrics.py" ] 
		then
			myprint "Running visual analysis in the background" 
			visual &
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

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load,	--novideo, --single, --pcap"
    echo "================================================================================"
    echo "--load       Page load max duration"
    echo "--iface      Network interface in use"
    echo "--novideo    Turn off video recording" 
    echo "--single     Just one test" 
    echo "--pcap       Collect pcap traces"
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
browser="chrome"
package="com.android.chrome"
activity="com.google.android.apps.chrome.Main"
myprint "[INFO] Cleaning browser data ($app-->$package)"
sudo pm clear $package
am start -n $package/$activity
sleep 10
chrome_onboarding
#browser_setup #FIXME => allow to skip chrome onboarding, but using a non working option

# get private  IP in use
my_ip=`ifconfig $interface | grep "\." | grep -v packets | awk '{print $2}'`
myprint "Interface: $interface IP: $my_ip" 

# loop across URLs to be tested
for((i=0; i<num_urls; i++))
do
    # get URL to be tested 
	if [ $single == "true" ] 
	then 
		let "i = RANDOM % num_urls"
	    url=${urlList[$i]} 
	    #url="https://cnn.com"
		myprint "Random URL: $url ($i)"
		i=$num_urls
	else 
	    url=${urlList[$i]} 
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
		sudo tcpdump -i $interface -w $pcap_file > /dev/null 2>&1 &
		disown -h %1  
		myprint "Started tcpdump: $pcap_file Interface: $interface"
	fi
    
	# run a test 
    run_test 
    
	# stop monitoring CPU
	myprint "Stop monitoring CPU"
	echo "false" > ".to_monitor"
	t_1=`date +%s`

	# take last screenshots 
	counter=0
	screen_file="${res_folder}/${id}-${curr_run_id}-${counter}.png"
	sudo screencap -p $screen_file
	sudo chown $USER:$USER $screen_file		
	t_last_scroll=0
	if [ -f ".time_last_scroll" ] 
	then
		t_last_scroll=`cat ".time_last_scroll"`
	fi
	let "time_passed = t_1 - t_last_scroll"
	if [ $time_passed -ge 3600 ] # only take one per hour, to save space 
	then
		take_screenshots &
		echo "$t_1" > ".time_last_scroll"
	fi 
	
   	# stop pcap collection and run analysis 
	tshark_size="N/A"
	if [ $pcap_collect == "true" ]
	then
		sudo killall tcpdump	
		myprint "Stopped tcpdump. Starting background analysis: $pcap_file"
		tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
		tshark_size=`cat $tshark_file | awk -F "," -v my_ip=$my_ip '{if($4!=my_ip){if($8=="UDP"){tot_udp += ($NF-8);} if($8=="TCP"){tot_tcp += ($11);}}}END{tot=(tot_tcp+tot_udp)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000}'`
		sudo rm $pcap_file
	fi
	myprint "Done with tshark analysis"
	
	# wait for screenshotting to be done
	while [ ! -f ".done-screenshots" ]
	do 
		sleep 2
		#myprint "Waiting for scrolling + screenshotting to be done!"
	done

	# close the browser
	close_all

	# make sure CPU background process is done
	t_2=`date +%s`
	let "t_sleep = 5 - (t_2 - t_1)"
	if [ $t_sleep -gt 0  -a $single != "true" ] 
	then 
		sleep $t_sleep
	fi 
	
	# log results
	myprint "[RESULTS]\tBrowser:$browser\tURL:$url\tBDW-LOAD:$traffic_before_scroll MB\tBDW-SCROLL:$traffic_after_scroll MB\tTSharkTraffic:$tshark_size\tLoadTime:$load_time"
done
