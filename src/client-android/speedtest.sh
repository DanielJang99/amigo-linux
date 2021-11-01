#!/bin/bash
## Author: Matteo Varvello 
## Date:   07/13/2021

# run a speed test 
run_speed_test(){
    # parameters
    browser_package="com.brave.browser"
    browser_activity="com.google.android.apps.chrome.Main"
    url="https://fast.com"
    LOAD_DUR=30
    curr_run_id=$1 

    # launch browser and wait for test to run
    adb -s $device_id shell am start -n $browser_package/$browser_activity -a $intent -d $url 
    sleep $LOAD_DUR    
    
    # take screenshot (text) 
    log_screen_fast="${res_folder}/screen-log-fast-${curr_run_id}.txt"
    adb -s $device_id exec-out uiautomator dump /dev/tty | awk '{gsub("UI hierchary dumped to: /dev/tty", "");print}' > $log_screen_fast

    # take actual screenshot (image) 
    screen_fast="${res_folder}/screenshot-fast-${curr_run_id}.png"
    adb -s $device_id exec-out screencap -p > $screen_fast

    # logging 
    myprint "Done with screenshots: screen-log-fast-${curr_run_id}.txt -- screenshot-fast-${curr_run_id}.png"
	
	#close open tabs and browser -- maybe optimized this 
	myprint "Closing all tabs"
    tap_screen 1000 2570 1 
    tap_screen 1280 2580 1 
    tap_screen 733 2025  
    myprint "Closing browser: $browser_package"
    adb -s $device_id shell am force-stop $browser_package

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
    
    # close open tabs 
	myprint "Closing all tabs"
    tap_screen 1280 2580 1 
    tap_screen 733 2025  

    # close the browser
    myprint "Closing browser: $browser_package"
    adb -s $device_id shell am force-stop $browser_package
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

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file 

# read XML file 
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

# test ip address  
test_ip(){
    # parameters
    browser_package="com.brave.browser"
    browser_activity="com.google.android.apps.chrome.Main"
    url="https://ifconfig.me/"
    LOAD_DUR=10
    adb -s $device_id shell am start -n $browser_package/$browser_activity -a $intent -d $url 
    sleep $LOAD_DUR
    adb -s $device_id exec-out uiautomator dump /dev/tty > ".ip"
    adb -s $device_id shell am force-stop $browser_package
}

# close open browser tabs 
close_tabs(){
    browser_package="com.brave.browser"
    browser_activity="com.google.android.apps.chrome.Main"
    tap_screen 760 2000 2 
    tap_screen 960 2000 2 
    tap_screen 385 1731 1 
    adb -s $device_id shell am force-stop $browser_package
}


# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    myprint "Trapped CTRL-C"
    safe_stop
}

# safe run interruption
safe_stop(){
    
    # go HOME and close all 
    close_all

    # turn screen off 
    #turn_device_off

    # all done
    myprint "[safe_stop] EXIT!"
    exit 0
}


# setup phone prior to an experiment 
phone_setup(){
    #get and log some useful info
    dev_model=`adb -s $device_id shell getprop ro.product.model | sed s/" "//g` # S9: SM-G960U
    android_vrs=`adb -s $device_id shell getprop ro.build.version.release`
    myprint "[INFO] DEV-MODEL: $dev_model ANDROID-VRS: $android_vrs"    
    if [ $dev_model != "SM-J337A" -a $dev_model != "SM-G960U" ]
    then 
        myprint "[ERROR] Device $dev_model is not supported yet"
        exit -1 
    fi

    # disable notification 
    myprint "[INFO] Disabling notifications for the experiment"
    adb -s $device_id shell settings put global heads_up_notifications_enabled 0

    # set desired brightness
    myprint "[INFO] Setting low screen brightness"
    screen_brightness=50
    adb -s $device_id shell settings put system screen_brightness $screen_brightness

    # remove screen timeout 
    myprint "[INFO] Remove screen timeout"
    max_screen_timeout="2147483647"
    adb -s $device_id shell settings put system screen_off_timeout $max_screen_timeout

    # close all pending applications
    close_all
    sleep 2 
}


# parameters 
device_id="LGH870eb6286bb"                   # default adb device identifier 
intent="android.intent.action.VIEW"          # default Intent in Android
crawl_id=`date +%s`                          # unique test identifier 
run_id=1                                     # default run identifier 

# read input if passed, if not default
if [ $# -eq 3 ] 
then  
	crawl_id=$2
	device_id=$2 
	run_id=$3
fi 	

# folder creationg
res_folder="./speed-testresults/$crawl_id"
mkdir -p $res_folder 

# run a speedtest 
run_speed_test $run_id

# logging 
myprint "[INFO] Pfiuuu All done -- Time: `date`"

# stop all need to be stopped 
safe_stop
