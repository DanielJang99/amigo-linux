#!/bin/bash
## Note:   Script to test one website at a time 
## Author: Matteo Varvello 
## Date:   08/09/2019

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

# import utilities files needed
curr_dir=`pwd`
adb_file=$curr_dir"/adb-utils.sh"
load_file $adb_file
browser_actions_file=$curr_dir"/browser-actions.sh"
load_file $browser_actions_file

# script usage
usage(){
    echo "==========================================================================================================================================================================================="
    echo "USAGE: $0 -u/--url, -b/--browser, -m/--monitor, -p/--proto, -d/--device, --moon, --id, -l/--light, --load, --rep,  --replay, --clean, --low, --compress, --video, --proxy, --moon"
    echo "==========================================================================================================================================================================================="
    echo "-u/--url        URL to be tested" 
    echo "-b/--browser    Browser to be used" 
    echo "-m/--monitor    Monitor CPU and bandwidth"
    echo "-l/--light      Switch to triggering using lighthouse"
    echo "-d/--device     ADB device identifier"
    echo "-p/--proto      HTTP Protocol to use [H1/H2]"
    echo "--moon          Monsoon data collection"
    echo "--id            Crawl identifier to use" 
	echo "--interact      Interact with a page or not (default = OFF)"
	echo "--load          Load time to wait for"
    echo "--rep           Optional repetition identifier"
    echo "--replay        Replay some human automation"
	echo "--clean         Clean browser state or not" 
	echo "--low           Wait for CPU to be low before a test" 
    echo "--compress      Compress monsoon logs"
	echo "--video         Record screen"
	echo "--proxy         Modify proxy setting" 
    echo "--moon          Monsoon data collection"
    echo "==========================================================================================================================================================================================="
    exit -1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	safe_stop
}

# safe run interruption
safe_stop(){
	myprint "Stop CPU monitor (give it 10 seconds...)"
	if [ $monitor == "true" ] 
	then 
   		echo "False" > ".to_monitor"
		to_monitor="False"
		sleep 10
	fi 
	stop_monsoon
	myprint "EXIT!"
	exit -1
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
	# reset all forwarding rules (needed by lighthouse)
	adb -s $device_id forward --remove-all

	# make sure no onboarding is given (verify potential caching issue) 
	use_persistent="true"
	if [ $use_persistent == "true" -a $app == "chrome" ] 
	then
		myprint "Disabling welcome tour. NOTE: this only works in Chrome unfortunately"
		#--disable-translate # not working, was it removed? 
		adb -s $device_id shell "echo \"${app} --disable-fre --no-default-browser-check --no-first-run --disable-notifications --disable-popup-blocking --enable-automation --disable-background-networking\" > /data/local/tmp/chrome-command-line"
		adb -s $device_id shell am set-debug-app --persistent $package
	else 
		# start browser
		myprint "[INFO] Launching $app ($package)."
		adb -s $device_id shell am start -n $package/$activity -a android.intent.action.VIEW

		# allow browser to load
		myprint "[INFO] Sleeping 5 secs for browser to load..."
		sleep 5

		# per browser fine grained automation
		browser_setup_automation $app $app_option $device_id $device $clean_browser
	   
		# make sure browser setup as the same duration (NOTE: t_setup might have an impact, actually)
		t_setup=15
		no_sync="true"
		myprint "Since not comparing browswers and using a proxy, avoiding sync among browsers" 
		if [ $no_sync == "true" ] 
		then 
			t_setup=0
		fi 	
		t_now=`date +%s`
		let "t_sleep = t_setup - (t_now - t_start_setup)"
		if [ $t_sleep -gt 0 ]
		then
			myprint "Browser setup sync. Sleeping for $t_sleep seconds..."
			sleep $t_sleep
		fi

		# stop browser (will be then relaunched) 
		myprint "[INFO] Closing $app ($package), skipp sleeping"
		#myprint "[INFO] Closing $app ($package) and sleep 15 seconds - TEMP (L112). Slower but make sure list is downloaded, if it i..."
		adb -s $device_id shell "am force-stop $package"
		#sleep 15 
	fi 

	# extra permission for H1/H2 testing (Brave only and our modified version) 
	#adb -s $device_id shell pm grant $package android.permission.READ_EXTERNAL_STORAGE
	#sleep 1
}

# replay some input autoamtion
action_replay(){
    if [ -f $action_file ]
    then
        # read actions
        c=0
        while read line
        do
            action_list[$c]="$line"
            let "c++"
        done < $action_file

        # execute actions
        i=0
        while [ $i -lt $c ]
        do
            action=${action_list[$i]}
            echo "eval $action"
            eval "$action"
            let "i++"
        done
    else
        echo "Action file $action_file is missing."
    fi
}


# run a test and collect data 
run_test(){
	# params 
	MAX_DURATION=60 
	
	# give more time to lighthouse  
	if [ $use_lighthouse == "true" ] 
	then 
		let "MAX_DURATION = MAX_DURATION + 30"
	fi 

	# low CPU barrier (if monsoon data collection is used and requested)
    if [ $use_monsoon == "true" -a $low_cpu == "true" ]
    then
        t_passed=0
        myprint "Low CPU sync barrier.T-passed: $t_passed"
        while [ ! -f ".ready_to_start" ]
        do
            myprint "Low CPU sync barrier. T-passed: $t_passed"
            sleep 5
            if [ $t_passed -gt 30 ]
            then
                myprint "WARNING - CPU barrier timeout (t_passed: $t_passed)"
                break
            fi
            let "t_passed += 5"
        done
        myprint "File \".ready_to_start\" was found!!!"
    fi

	# start monsoon data collection (if requested)
    if [ $use_monsoon == "true" ]
    then
        t_start_monsoon=`date +%s`
        myprint "[INFO] Starting monsoon data collection"
        sudo rm ".t_monsoon" > /dev/null 2>&1
        monsoon_data_collect
        myprint "monsoon sync barrier..."
        f_found="false"
        while [ $f_found == "false" ]
        do
            if [ -f ".t_monsoon" ]
            then
                t_start_sync=`cat .t_monsoon`
                myprint "monsoon sync barrier - t_start_sync: $t_start_sync"
                f_found="true"
            else
                t_start_sync=`date +%s`
            fi
            sleep 0.1
        done
    fi

	# get initial network data information
    pi_start=`cat /proc/net/dev | grep $interface  | awk '{print $10}'`
	device_last=`adb -s $device_id shell cat /proc/net/dev | grep -w wlan0 | awk '{print $10}'`
    pi_last=$pi_start
    compute_bandwidth
    traffic_rx=$curr_traffic
    traffic_rx_last=$traffic_rx
    myprint "[INFO] App: $app Abs. Bandwidth: $traffic_rx Pi-bdw: $pi_start"

	# manage screen recording
	if [ $video_recording == "true" ]
	then
    	t=`date +%s`
    	screen_video="/sdcard/last-run-$t"
	    (adb -s $device_id shell screenrecord $screen_video".mp4" &)
	fi

	# attempt page load and har extraction
	myprint "URL: $url PROTO: $PROTO  RES-FOLDER: $res_folder TIMEOUT: $MAX_DURATION USE-LIGHTHOUSE: $use_lighthouse"
	t_launch=`date +%s`
	if [ $use_lighthouse == "true" ] 
	then 
		#timeout $MAX_DURATION lighthouse $url --max-wait-for-load $load_time --port=$DEVTOOL_PORT --save-assets --emulated-form-factor=none --throttling-method=provided --output-path=$res_folder$id --output=json 
		timeout $MAX_DURATION lighthouse $url --max-wait-for-load $load_time --port=$DEVTOOL_PORT --save-assets --throttling-method=provided --output-path=$res_folder$id --output=json 
		#timeout $MAX_DURATION lighthouse --port=$DEVTOOL_PORT --save-assets --emulated-form-factor=none --throttling-method=provided --output-path=$res_folder/$id "https://"$url >  $log_run 2>&1
		if [ -f $res_folder/$id ] 
		then 
			mv $res_folder/$id $res_folder/$id".html"
		fi 
	else 
		adb -s $device_id shell am start -n $package/$activity -a $intent -d $url 
		t_now=`date +%s`
		let "t_start_dur = t_now - t_launch"
		if [ $replay == "true" ] 
		then 
			action_replay
			myprint "[INFO] Completed action replay"
		else
			let "sleep_time = load_time/2"
			sleep $sleep_time
			if [ $clean_browser == "true" ] 
			then 
				#if [ $app == "chrome" ]  # WARNING -- not happening? 
				#then
				#	myprint "WARNING. Turning lite mode off for Chrome"
				#	adb -s $device_id shell "input tap 214 928"
				if [ $app == "duckduckgo" ]
				then
					myprint "WARNING. Accepting duckduckgo tip"
					adb -s $device_id shell "input tap 366 1164"
				elif [ $app == "opera" ]
				then
					myprint "WARNING. Accepting opera notificaiton for adblocking" 
					adb -s $device_id shell "input tap 366 1164"
				fi
			fi 
			sleep $sleep_time
			
		    # interact with the page
			time_int=15
			if [ $user_interaction == "true" ]
			then
				myprint "Starting page interaction (duration: $time_int)"
				page_interact $time_int
			fi
		fi 
	fi 

	# stop video recording 
	if [ $video_recording == "true" ]
	then
		pid=`ps aux | grep "screenrecord" | grep -v "grep" | awk '{print $2}'`
		kill -9 $pid
		sleep 1
		adb -s $device_id pull $screen_video".mp4" ./
		adb -s $device_id shell rm $screen_video".mp4"
		final_screen_video=$res_folder"/"$id".mp4"	
		perf_video=$res_folder"/"$id".perf"	
		last_frame=$res_folder"/"$id".png"	
		local_screen_video=`echo $screen_video | awk -F "/" '{print $NF}'`
		mv $local_screen_video".mp4" $final_screen_video
		myprint "[INFO] LocalVideo: $local_screen_video Video: $final_screen_video Perf: $perf_video"
		#if [ -f "visualmetrics/visualmetrics.py" ] 
		#then 
		#	(python visualmetrics/visualmetrics.py --video $final_screen_video --viewport --orange > $perf_video 2>&1 &)
		#	#(python visualmetrics/visualmetrics.py --video $final_screen_video --dir frames -q 75 --histogram histograms.json.gz --orange --viewport > $perf_video 2>&1 &)
		#fi 
		
		# extract last frame (also in the background) 
 		#(ffmpeg -sseof -3 -i $final_screen_video -update 1 -q:v 1 $last_frame > /dev/null 2>&1 &)
 		#(last_video_frame $final_screen_video $last_frame &)
	fi	
	
	# update traffic rx (for this URL)
	compute_bandwidth $traffic_rx_last
	pi_curr=`cat /proc/net/dev | grep $interface  | awk '{print $10}'`
	device_curr=`adb -s $device_id shell cat /proc/net/dev | grep -w wlan0 | awk '{print $10}'`
	pi_traffic=`echo "$pi_curr $pi_last" | awk '{traffic = ($1 - $2)/1000000; print traffic}'` #MB
	device_traffic=`echo "$device_curr $device_last" | awk '{traffic = ($1 - $2)/1000000; print traffic}'` #MB
	pi_last=$pi_curr
	traffic_rx_last=$curr_traffic
	#myprint "URL: $url Bandwidth: $traffic MB PI-BDW: $pi_traffic MB"
	
	# log results 
	energy="N/A"
	t_now=`date +%s`
	if [ $use_monsoon == "true" ]
	then
		echo "python quick-enery-calc.py $monsoon_log $t_start_sync $t_launch $t_now"
		energy=`python quick-enery-calc.py $monsoon_log $t_start_sync $t_launch $t_now mah`
	fi
	let "duration = t_now - t_launch"
	myprint "[RESULTS]\tBrowser:$browser\tRep:$rep\tURL:$url\tBandwidth:$traffic MB\tDEVICE-BDW:$device_traffic\tPI-BDW:$pi_traffic MB\tEnergy:$energy\tLaunchDuration:$t_start_dur\tTotDuration:$duration sec"
	echo -e "$traffic\t$pi_traffic" > $log_traffic

	# close the browser
	myprint "[INFO] Closing $app ($package)"
	adb -s $device_id shell am force-stop $package
}

# parameters 
device=""                                         # human readable device name 
package="com.brave.browser"                       # Brave package (Android)
activity="com.google.android.apps.chrome.Main"    # Main intent
intent="android.intent.action.VIEW"               # default Intent in Android
declare -gA dict_packages                         # dict of browser packages
declare -gA dict_activities                       # dict of browser activities
curl_timeout=20                                   # maximum duration for curl pre-test 
browser="brave"                                   # Browser to use on Desktop 
monitor="false"                                   # Control if to monitor cpu/bandwdith or not
proto="H2"                                        # HTTP protocol to use 
url="www.google.com"                              # default URL to test 
use_monsoon="false"                               # collect power measurements
crawl_id=`date +%s`                               # crawl identifier 
use_lighthouse="false"                            # use lighthouse or not  
PROTO="h2"                                        # default protocol to use 
app_option="None"                                 # extra app option Q: is it still useful? 
def_port=5555                                     # default port for adb over wifi
interface="wlan0"                                  # current default interface where to collect data
load_time=30                                      # default load time 
rep=0                                             # default repetition is zero 
DEVTOOL_PORT=9222                                 # default port to be used for devtools
replay="false"                                    # replay some human automation 
clean_browser="false"                             # by default, do not clean the browser
user_interaction="false"                          # interact with page or not
low_cpu="false"                                   # wait for CPU to be low before to start a test 
compress_log="false"                              # compress logs or not 
video_recording="false"                           # record screen or not
proxy_switch="false"                              # unless a proxy is passed, do nothign with the proxy setting 

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        -u | --url)
            shift;
			# ensure https
			base_url=`echo "$1" | sed s/"https:\/\///g" | sed s/"http:\/\///g"`
			url="https://"$base_url
			shift;
			;;
		-b | --browser)
            shift;
			app_option=`echo "$1" | cut -f 2 -d "-" | tr '[:upper:]' '[:lower:]'`
			browser=`echo "$1" | cut -f 1 -d "-" | tr '[:upper:]' '[:lower:]'`
			app=$browser
			shift; 
			;;
		-d | --device)
            shift; device="$1"; shift; 
			;;
		-p | --proto)
            shift;proto="$1";shift; 
			;;
		-l | --light)
			use_lighthouse="true"; shift; 
			;;
		-m | --monitor)
            shift; monitor="true";
			;;
		--moon)
            shift; use_monsoon="true";
			;;
		--id)
            shift; crawl_id="$1"; shift; 
			;;
		 --interact)
            shift; user_interaction="true";
            ;;
		--load)
            shift; load_time="$1"; shift; 
			;;
		--rep)
            shift; rep="$1"; shift; 
			;;
		--replay)
			shift; replay="true"; action_file="$1"; shift; 
			;;
		--clean)
			shift; clean_browser="true"; 
			;;
		--low)
			shift; low_cpu="true"; 
			;;
		--compress)
            shift; compress_log="true";
            ;;
        --video)
            shift; video_recording="true";
            ;;
		--proxy)
            shift; proxy_addr=$1;shift;
			proxy_switch="true"
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

# check for errors 
if [ -z $device ] 
then 
	myprint "No device was requested" 
	usage
fi 

# make sure there is enough space on the device
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`
is_full=`echo "$free_space $MIN_SPACE" | awk '{if($1 <= $2) print "true"; else print "false";}'`
if [ $is_full == "true" ]
then
    myprint "ERROR -- Low hard disk space detected ($free_space <= $MIN_SPACE)."
    exit -1
fi
myprint "Current free  space on hard disk: $free_space GB"

# make sure URL works (unless test is called by master, which does it for us)
ps aux | grep "master-website-tester.sh" | grep -v "grep\|vi" > /dev/null 2>&1 
if [ $? == 1 ] 
then 
	timeout $curl_timeout curl $url > /dev/null 2>&1
	error_code=$?
	myprint "[CURL Test] URL: $url Error-code: $error_code"
	if [ $error_code -ne 0 ]
	then
		myprint "URL seems to have some issues" 
		exit 0
	fi
fi 

# retrieve info about device under test
get_device_info "phones-info.json" $device
if [ -z $adb_identifier ]
then
    myprint "Device $device not supported yet"
    exit -1
fi
usb_device_id=$adb_identifier
device_ip=$ip
device_mac=$mac_address
width=`echo $screen_res | cut -f 1 -d "x"`
height=`echo $screen_res | cut -f 2 -d "x"`

# find device id to be used and verify all is good
if [ $device == "SM-J337A" ] 
then
    # detect if to use IP from local wifi (e.g., during a monsoon test) 
    identify_device_id
    
    # verify that wifi works
    wifi_test
    if [ $? -ne 0 ]
    then 
      exit 1 
    fi 
else 
    device_id=$usb_device_id
fi 

# prepping for  lighthouse
if [ $use_lighthouse == "true" ] 
then 
	#adb kill-server
	#adb devices
	echo "Activating port forwarding for devtools (port: $DEVTOOL_PORT)"
	adb -s $device_id forward --remove-all
	adb -s $device_id forward tcp:$DEVTOOL_PORT localabstract:chrome_devtools_remote
	#sleep 10 
fi 

# make sure the screen is ON
turn_device_on

# load browser package and activity needed
load_browser

# package and activity selection based on browser under test
app_info

# make sure device is unlocked 
if [ $device == "SM-J337A" ] 
then 
	foreground=`adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
	echo $foreground
	if [[ "$foreground" == *"StatusBar"* ]]
	then 
		myprint "Device is locked. Attempting unlock..."
		adb -s $device_id shell input swipe 360 1040 360 100
		adb -s $device_id shell "input tap 150 750"
		for ((i=1; i<=3; i++))
		do 
			adb -s $device_id shell "input tap 360 750"
		done 
		sleep 5 
		foreground=`adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
		if [ $foreground == "com.sec.android.app.launcher" ] 
		then 
			myprint "Unlock worked, test can continue"
		fi 
	else 
		myprint "Device is unlocked"
	fi 
elif [ $device == "SM-G973U1" ] 
then 
	curr_state=`adb -s $device_id shell dumpsys nfc | grep 'Screen State' | cut -f 2 -d ":" | sed -e 's/^[ \t]*//'`
	myprint "Device is in state $curr_state"
	if [[ "$curr_state" == *"OFF"* ]]
	then
		adb -s $device_id shell "input keyevent KEYCODE_POWER"
		sleep 3
	fi
	curr_state=`adb -s $device_id shell dumpsys nfc | grep 'Screen State' | cut -f 2 -d ":" | sed -e 's/^[ \t]*//'`
	myprint "Device is in state $curr_state"
	if [ $curr_state == "ON_LOCKED" ]
	then
		adb -s $device_id shell input swipe 360 1040 360 100
		adb -s $device_id shell "input tap 285 1140"
		for ((i=1; i<=3; i++))
		do
			adb -s $device_id shell "input tap 540 1140"
		done
	fi
fi 

# phone preparation for test
phone_setup_simple
if [ $? -eq 1 ]
then
    myprint "Something went wrong during phone_setup (adb-utils.sh)"
    exit 1
fi
adb -s $device_id shell settings put system screen_brightness 70

# folder organization 
res_folder=$curr_dir"/website-testing-results/"$crawl_id"/"$app"/"$rep
mkdir -p $res_folder
myprint "Results can be found at: $res_folder"

# disable H2 if requested (need a special .apk) 
if [ $proto == "H1" ] 
then 
	adb -s $device_id push protoH1.txt /sdcard/proto.txt
fi 

# remove proxy usage 
if [ $proxy_switch == "true" ] 
then 
	myprint "Remove proxy usage (e.g., allows Brave to fetch adblock list)"
	adb -s $device_id shell settings put global http_proxy ":0"
	adb -s $device_id shell settings put global https_proxy ":0"
fi 

# clean browser state
if [ $clean_browser == "true" ] 
then 
    myprint "[INFO] Cleaning app data ($app-->$package)"
	adb -s $device_id shell pm clear $package
    pi_last=`cat /proc/net/dev | grep $interface  | awk '{print $10}'`
	browser_setup
    pi_curr=`cat /proc/net/dev | grep $interface  | awk '{print $10}'`
	pi_traffic=`echo "$pi_curr $pi_last" | awk '{traffic = ($1 - $2)/1000000; print traffic}'` #MB
    myprint "[INFO] Pi traffic consumed during browser setup: $pi_traffic MB"
fi 

# restore proxy
if [ $proxy_switch == "true" ] 
then 
	myprint "Restore proxy usage"
	adb -s $device_id shell settings put global http_proxy $proxy_addr
	adb -s $device_id shell settings put global https_proxy $proxy_addr
fi 

# file naming
id=`echo $url | md5sum | cut -f1 -d " "`
har_file=$res_folder"/"$id".har"
out_file=$res_folder"/"$id".out"
log_cpu=$res_folder"/"$id".cpu"
log_traffic=$res_folder"/"$id".traffic"
log_run=$res_folder"/"$id".run"
log_tcp=$res_folder"/"$id".tcp"
data_file=$res_folder"/"$id".perf"
monsoon_log=$res_folder"/"$id".batt"

# start background procees to monitor CPU on the device
clean_file $log_cpu
myprint "Starting cpu monitor. Log: $log_cpu"
echo "true" > ".to_monitor"
clean_file ".ready_to_start"
cpu_monitor $log_cpu &

# run a test 
run_test 

# stop monsoon data collection
stop_monsoon

# stop monitoring CPU
echo "false" > ".to_monitor"
#sleep 5

# re-enable notifications and screen timeout
myprint "[INFO] ALL DONE -- Re-enabling notifications and screen timeout"
adb -s $device_id shell settings put global heads_up_notifications_enabled 1
adb -s $device_id shell settings put system screen_off_timeout 600000

# compress monsoon logs if requested
if [ $compress_log == "true" ]
then
    num=`wc -l $monsoon_log | cut -f 1 -d " "`
    cat $monsoon_log | awk '{if ((NR%100)==0) print $0}' > t
    sudo mv t $monsoon_log
    num_new=`wc -l $monsoon_log | cut -f 1 -d " "`
    myprint "Compressed Monsoon logs: $num --> $num_new"
fi

# all good 
echo "DONE :-)"
