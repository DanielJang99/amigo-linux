#!/bin/bash
## Author: Matteo Varvello 
## Date:   07/13/2021

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


# read XML file 
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}


# run a speed test 
run_speed_test(){
    # parameters
    browser_package="com.brave.browser"
    browser_activity="com.google.android.apps.chrome.Main"
	url="https://fast.com"
    curr_run_id=$1 

    # launch browser and wait for test to run
    adb -s $device_id shell am start -n $browser_package/$browser_activity -a $intent -d $url 
    sleep $load_time
	
	# click "pause" - not deterministic
	#tap_screen 1090 1300 2

    # take screenshot (text) 
    log_screen_fast="${res_folder}/screen-log-fast-${curr_run_id}.txt"
    adb -s $device_id exec-out uiautomator dump /dev/tty | awk '{gsub("UI hierchary dumped to: /dev/tty", "");print}' > $log_screen_fast

    # take actual screenshot (image) 
    screen_fast="${res_folder}/screenshot-fast-${curr_run_id}.png"
    adb -s $device_id exec-out screencap -p > $screen_fast

    # logging 
    myprint "Done with screenshots: screen-log-fast-${curr_run_id}.txt -- screenshot-fast-${curr_run_id}.png"
	
	#close open tabs
	ans=$(($curr_run_id % 5))
	#if [ $ans -eq 0 ] 
	if [ $ans -eq 0 -a $curr_run_id -gt 0 ] 
	then 
		close_brave_tabs
	else 
		# closing Brave 
		myprint "Closing browser: $browser_package"
		adb -s $device_id shell am force-stop $browser_package
	fi 

	# skipping analysis for now 
	return 0 

    # extract speedtest results 
    speed_val="N/A"
    speed_unit="N/A"
    upload_speed="N/A"
    upload_unit="N/A"
    user_ip="N/A"
    location="N/A"
    unloaded_latency="N/A"
    unloaded_latency_unit="N/A"
    loaded_latency="N/A"
    loaded_latency_unit="N/A"
    server_location="N/A"
    res_mode="XML"
    while read_dom
    do 
        # extract speedtest results 
        if [[ "$ENTITY" == *"speed-value"* ]]; then
            speed_val=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"speed-units"* ]]; then
            speed_unit=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"user-location"* ]]; then
            location=`echo "$ENTITY" | cut -f 3 -d "=" | sed 's/"//g' |  sed 's/ resource-id//g'`    
        elif [[ "$ENTITY" == *"user-ip"* ]]; then
             user_ip=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"upload-value"* ]]; then
            upload_speed=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"upload-units"* ]]; then
            upload_unit=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`    
        elif [[ "$ENTITY" == *"latency-value"* ]]; then
            unloaded_latency=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"latency-units"* ]]; then
            unloaded_latency_unit=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`    
        elif [[ "$ENTITY" == *"bufferbloat-value"* ]]; then
            loaded_latency=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`
        elif [[ "$ENTITY" == *"bufferbloat-units"* ]]; then
            loaded_latency_unit=`echo "$ENTITY" | awk '{split($3, a, "="); gsub("\"","", a[2]); print a[2]}'`    
        elif [[ "$ENTITY" == *"server-locations"* ]]; then
            server_location=`echo "$ENTITY" | cut -f 3 -d "=" | sed 's/"//g' |  sed 's/ resource-id//g'`  
        fi 
    done < $log_screen_fast
    
    # perform OCR in case ^^ did not work 
    if [ $speed_val == "N/A" ]
    then 
        screen_fast_ocr="${res_folder}/ocr-fast-${curr_run_id}"
        myprint "Text screenshot did not work. Attempting OCR: ocr-fast-${curr_run_id}.txt"
        filename=`echo $screen_fast | awk -F "/" '{print $NF}'`
        prefix=`echo $filename | cut -f 1 -d "."`
        suffix=`echo $filename | cut -f 2 -d "."`
        screen_fast_processed="${res_folder}/${prefix}_processed.${suffix}"
		myprint "HERE-- Prefix:$prefix -- Suffix:$suffix"
        if [ ! -f $screen_fast_processed ]
        then 
            echo "Image optimization to help OCR..."
            convert $screen_fast -type Grayscale "temp.${suffix}"  
            convert "temp.${suffix}" -gravity South -chop 0x600 $screen_fast_processed
            convert $screen_fast_processed -gravity North -chop 0x600 "temp.${suffix}"  
            mv "temp.${suffix}" $screen_fast_processed
        fi 
        screen_fast_ocr="${res_folder}/ocr-fast-${curr_run_id}"
        tesseract -l eng $screen_fast_processed $screen_fast_ocr > /dev/null 2>&1
        screen_fast_ocr="${res_folder}/ocr-fast-${curr_run_id}.txt"
        cat $screen_fast_ocr  | sed -r '/^\s*$/d' > .last-ocr 
        mv .last-ocr $screen_fast_ocr
        speed_val=`cat $screen_fast_ocr  | grep -A 1 "speed" | grep -v "speed" | sed 's/[^\u2103]//g'`
        speed_unit="Mbps" # unfortunately speedunit can only be guessed...        
        if [ $speed_val -gt 50 ] 
        then
            speed_unit="Kbps"
        fi 
        ans=`cat $screen_fast_ocr | grep ms  | awk 'BEGIN{isnum=0; newval=""; first=0;}{for(i=1; i<=NF; i++){if (substr($i,1,1) ~ /^[0-9]/) {newval=newval$i}else{if(first==0){ans=newval" "$i; first=1;} else {ans=ans" "newval" "$i;} newval="";}}}END{print ans}'`
        unloaded_latency=`echo $ans | cut -f 1 -d " "`
        unloaded_latency_unit=`echo $ans | cut -f 2 -d " "`
        loaded_latency=`echo $ans | cut -f 3 -d " "`
        loaded_latency_unit=`echo $ans | cut -f 4 -d " "`
        upload_speed=`echo $ans | cut -f 5 -d " "`
        upload_unit=`echo $ans | cut -f 6 -d " "`
        ans=`cat $screen_fast_ocr   | grep "Client"`
        user_ip=`echo $ans  | awk '{print $NF}'`
        location=`echo $ans | sed 's/Client//' | sed "s/$user_ip//"`        
        server_location=`cat $screen_fast_ocr   | grep -A 1 "Server" | sed 's/Server(s)//' | tr '\n' ' '` 
        res_mode="OCR"
    fi 
     
    # logging 
    speed_res="${res_folder}/speedtest-results-${curr_run_id}.txt"
    myprint "[SPEEDTEST][${curr_run_id}][$res_mode] ${speed_val}${speed_unit}\t${upload_speed}${upload_unit}\t${unloaded_latency}${unloaded_latency_unit}\t${loaded_latency}${loaded_latency_unit}\t${user_ip}\t${location}\t${server_location}"
    echo -e "${speed_val}${speed_unit}\t${upload_speed}${upload_unit}\t${unloaded_latency}${unloaded_latency_unit}\t${loaded_latency}${loaded_latency_unit}\t${user_ip}\t${location}\t${server_location}\t${mode}" > $speed_res
    
    # logging 
    myprint "Speedtest results reported: speedtest-results-${curr_run_id}.txt"
    
    # close open tabs  #MV -- skipping since in next step browser is cleared
	#myprint "Closing all tabs"
    #tap_screen 1280 2580 1 
    #tap_screen 733 2025  

    # close the browser
    #myprint "Closing browser: $browser_package"
    #adb -s $device_id shell am force-stop $browser_package
}


# # setup phone prior to an experiment 
# phone_setup(){
#     #get and log some useful info
#     dev_model=`adb -s $device_id shell getprop ro.product.model | sed s/" "//g` # S9: SM-G960U
#     android_vrs=`adb -s $device_id shell getprop ro.build.version.release`
#     myprint "[INFO] DEV-MODEL: $dev_model ANDROID-VRS: $android_vrs"    
#     if [ $dev_model != "SM-J337A" -a $dev_model != "SM-G960U" ]
#     then 
#         myprint "[ERROR] Device $dev_model is not supported yet"
#         exit -1 
#     fi

#     # disable notification 
#     myprint "[INFO] Disabling notifications for the experiment"
#     adb -s $device_id shell settings put global heads_up_notifications_enabled 0

#     # set desired brightness
#     myprint "[INFO] Setting low screen brightness"
#     screen_brightness=50
#     adb -s $device_id shell settings put system screen_brightness $screen_brightness

#     # remove screen timeout 
#     myprint "[INFO] Remove screen timeout"
#     max_screen_timeout="2147483647"
#     adb -s $device_id shell settings put system screen_off_timeout $max_screen_timeout

#     # close all pending applications
#     close_all
#     sleep 2 
# }


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
	#--disable-translate # not working, was it removed? 
	adb -s $device_id shell "echo \"${app} --disable-fre --no-default-browser-check --no-first-run --disable-notifications --disable-popup-blocking --enable-automation --disable-background-networking\" > /data/local/tmp/chrome-command-line"
	adb -s $device_id shell am set-debug-app --persistent $package
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
    	screen_video="/sdcard/run-$device_id-$t"
	    (adb -s $device_id shell screenrecord $screen_video".mp4" &) #--bit-rate 1000000
	fi

	# attempt page load and har extraction
	myprint "URL: $url PROTO: $PROTO  RES-FOLDER: $res_folder TIMEOUT: $MAX_DURATION"
	t_launch=`date +%s`
	adb -s $device_id shell am start -n $package/$activity -a $intent -d $url 
	t_now=`date +%s`
	#if [ $url == "https://www.cnn.com" ] 
	#then 
	#	let "left_time = load_time/2"
	#else 
	#	left_time=5
	#fi 
	#let "most_lod_time = load_time - $left_time"
	#sleep $most_lod_time
	#accept_cookies $url
	#sleep $left_time
	sleep $load_time 

	# stop video recording 
	if [ $video_recording == "true" ]
	then
		pid=`ps aux | grep "screenrecord" | grep "$device_id" | grep -v "grep" | awk '{print $2}'`
		myprint "Found video process: $pid (device:$device_id)" 
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
	traffic_rx_last=$curr_traffic
	
	# log results 
	energy="N/A"
	t_now=`date +%s`
	let "duration = t_now - t_launch"
	myprint "[RESULTS]\tBrowser:$browser\tRep:$run_id\tURL:$url\tAPP-BDW:$traffic MB\tLaunchDuration:$t_start_dur\tTotDuration:$duration sec"
	echo -e "$traffic\t$pi_traffic" > $log_traffic

	# close the browser
	myprint "[INFO] Closing $app ($package)"
	adb -s $device_id shell am force-stop $package
}

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 -d/--device, --id,	--novideo"
    echo "================================================================================"
    echo "-d/--device     Device name from phone-info.json"
    echo "--id            Crawl identifier to use"
    echo "--novideo       Turn off video recording" 
    echo "================================================================================"
    exit -1
}

# parameters 
device_id="LGH870eb6286bb"                        # default adb device identifier 
intent="android.intent.action.VIEW"               # default Intent in Android
crawl_id=`date +%s`                               # unique test identifier 
run_id=0                                          # default run identifier 
device=""                                         # human readable device name 
intent="android.intent.action.VIEW"               # default Intent in Android
declare -gA dict_packages                         # dict of browser packages
declare -gA dict_activities                       # dict of browser activities
browser="chrome"                                  # Browser to use on Desktop 
app="chrome"                                      # Browser to use on Desktop 
monitor="false"                                   # Control if to monitor cpu/bandwdith or not
url="www.google.com"                              # default URL to test 
app_option="None"                                 # extra app option Q: is it still useful? 
load_time=30                                      # default load time 
clean_browser="false"                             # by default, do not clean the browser
video_recording="true"                            # record screen or not
use_monsoon="false"                               # by default no monsoon usage 
interface="wlan"

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        --id)
            shift; crawl_id="$1"; shift;
            ;;
        -d | --device)
            shift; device="$1"; shift;
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

# check for errors 
if [ -z $device ] 
then 
    myprint "No device was requested" 
    usage
fi 

#####WARNING
myprint "WARNING. Using interface $interface"
#####WARNING

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
device_id=$usb_device_id

# folder creation
res_folder="./speedtest-results/$device/$crawl_id"
mkdir -p $res_folder 
res_folder="./website-testing-results/$device/$crawl_id/"
mkdir -p $res_folder
    
# make sure the screen is ON
turn_device_on

# load browser package and activity needed
load_browser

# package and activity selection based on browser under test
app_info

# # phone preparation for test
# phone_setup_simple
# if [ $? -eq 1 ]
# then
#     myprint "Something went wrong during phone_setup (adb-utils.sh)"
#     exit 1
# fi

# load urls to be tested
url_file="urls_list.txt"
num_urls=0
while read line
do 
    urlList[$num_urls]="$line"
    let "num_urls++"
done < $url_file

# loop for the whole experiment duration 
DURATION=86400
t_start=`date +%s`
t_current=`date +%s`
let "t_p = t_current - t_start"
while [ $t_p -lt $DURATION ]
do
    # get URL to be tested 
    id=$(($run_id % $num_urls))
    url=${urlList[$id]} 
    
    # update res_folder for next test
    res_folder="./website-testing-results/$device/$crawl_id/"
    
    # clean the browser
    myprint "[INFO] Cleaning app data ($app-->$package)"
    adb -s $device_id shell pm clear $package
    browser_setup
    
    # file naming
    id=`echo $url | md5sum | cut -f1 -d " "`"-"$run_id
    log_cpu=$res_folder"/"$id".cpu"
    log_traffic=$res_folder"/"$id".traffic"
    log_run=$res_folder"/"$id".run"
    
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

    # run a speedtest 
	res_folder="./speedtest-results/$device/$crawl_id"
    #run_speed_test $run_id
	myprint "WARNING: speedtest disabled!!!"

    # increase run counter 
    let "run_id++"
done

# re-enable notifications and screen timeout
myprint "[INFO] ALL DONE -- Re-enabling notifications and screen timeout"
adb -s $device_id shell settings put global heads_up_notifications_enabled 1
adb -s $device_id shell settings put system screen_off_timeout 600000

# all good 
echo "DONE :-)"
