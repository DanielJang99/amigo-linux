#!/bin/bash
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
	myprint "Stop CPU monitor (give it 10 seconds...)"
	if [ $monitor == "true" ] 
	then 
   		echo "False" > ".to_monitor"
		to_monitor="False"
		sleep 10
	fi 
	
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


# helper to extra last frame of a video
last_video_frame(){
	fn="$1"
 	of="$2"
	suffix=`echo $fn | awk -F "/" '{print $NF}'| cut -f 1 -d "."`
	lf=`ffprobe -show_streams "$fn" 2> /dev/null | awk -F= '/^nb_frames/ { print $2-1 }'`
 	rm -f "$of"
 	#echo "ffmpeg -i \"$fn\" -vf \"select=\'eq(n,$lf)\'\" -vframes 1 \"$of\""
 	ffmpeg -i "$fn" -vf "select='eq(n,$lf)'" -vframes 1 "$of" > "debvideologs/"$suffix".log" 2>&1
}

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
    myprint "[INFO] App: $app Abs. Bandwidth: $traffic_rx"

	# manage screen recording
	if [ $video_recording == "true" ]
	then
    	t=`date +%s`
    	screen_video="${res_folder}/${id}-${curr_run_id}.mp4"
    	perf_video="${res_folder}/${id}-${curr_run_id}.perf"
	    (sudo screenrecord $screen_video &) #--bit-rate 1000000
		myprint "Started screen recording on file: $screen_video"
	fi

	# attempt page load and har extraction
	myprint "URL: $url PROTO: $PROTO  RES-FOLDER: $res_folder TIMEOUT: $MAX_DURATION"
	t_launch=`date +%s`
	am start -n $package/$activity -a $intent -d $url 
	t_now=`date +%s`
	sleep $load_time 

	# stop video recording and run we perf analysis
	if [ $video_recording == "true" ]
	then
		myprint "Stopping screen recording"
		for pid in `sudo ps aux | grep "screenrecord" | grep $screen_video | awk '{print $2}'`
		do  
			sudo kill -9 $pid > /dev/null 2>&1
		done
		sleep 1
		sudo chown $USER:$USER $screen_video
		if [ -f "visualmetrics/visualmetrics.py" ] 
		then 
			myprint "Running visualmetrics/visualmetrics.py (background - then should do browser prep...?)"
			(python visualmetrics/visualmetrics.py --video $screen_video --viewport --orange > $perf_video 2>&1 &)
			#(python visualmetrics/visualmetrics.py --video $final_screen_video --dir frames -q 75 --histogram histograms.json.gz --orange --viewport > $perf_video 2>&1 &)
		fi 
		
		# extract last frame (also in the background) 
 		#(ffmpeg -sseof -3 -i $final_screen_video -update 1 -q:v 1 $last_frame > /dev/null 2>&1 &)
 		#(last_video_frame $final_screen_video $last_frame &)
	fi	
	
	# update traffic rx (for this URL)
	compute_bandwidth $traffic_rx_last
	traffic_rx_last=$curr_traffic
	
	# log results 
	energy="N/A"
	t_now=`date +%s`
	let "duration = t_now - t_launch"
	myprint "[RESULTS]\tBrowser:$browser\tURL:$url\tBDW:$traffic MB\tLoadTime:$load_time"

	# close the browser
	close_all
}

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load,	--novideo"
    echo "================================================================================"
    echo "--load       Page load max duration"
    echo "--novideo    Turn off video recording" 
    echo "================================================================================"
    exit -1
}

# parameters 
monitor="false"                    # Control if to monitor cpu/bandwdith or not
url="www.google.com"               # default URL to test 
load_time=30                       # default load time 
video_recording="true"             # record screen or not
interface="wlan0"                  # default network interface to monitor (for traffic)

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
        -h | --help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

#####WARNING
myprint "WARNING. Using interface $interface"
#####WARNING

# folder creation
suffix=`date +%d-%m-%Y`
curr_run_id=`date +%s`    
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
sleep 2
chrome_onboarding
#browser_setup #FIXME => allow to skip chrome onboarding, but using a non working option
    
# loop across URLs to be tested
for((i=0; i<num_urls; i++))
do
    # get URL to be tested 
    url=${urlList[$i]} 
    
    # file naming
    id=`echo $url | md5sum | cut -f1 -d " "`"-"$i
    log_cpu="${res_folder}/${id}-${curr_run_id}.cpu"
    log_traffic="${res_folder}/${id}-${curr_run_id}.traffic"
    log_run="${res_folder}/${id}-${curr_run_id}.run"
    
    # start background process to monitor CPU on the device
    clean_file $log_cpu
    myprint "Starting cpu monitor. Log: $log_cpu"
    echo "true" > ".to_monitor"
    clean_file ".ready_to_start"
    cpu_monitor $log_cpu &

    # run a test 
    run_test 
    
    # stop monitoring CPU
    echo "false" > ".to_monitor"
done
