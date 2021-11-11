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
    #browser_package="com.brave.browser" #Brave and Kiwi crashed (too much memory)
    browser_package="com.android.chrome"
    browser_activity="com.google.android.apps.chrome.Main"
    url="https://fast.com"
    load_time=30

    # launch browser and wait for test to run
    am start -n $browser_package/$browser_activity -d $url 
    sleep $load_time
		
	# keep track of opened tabs
	num_tabs=0
	if [ -f ".brave-tabs" ] 
	then 
		num_tabs=`cat ".brave-tabs"`
	fi
	let "num_tabs++"
	echo $num_tabs > ".brave-tabs"

	# click "pause" - not deterministic
	#tap_screen 1090 1300 2
		
	echo "Click more info.."
	tap_screen 370 830 1
	sleep 3 
	echo "Click pause..."
	tap_screen 534 636 1

    # take screenshot (text) 
    sudo uiautomator dump /dev/tty | awk '{gsub("UI hierchary dumped to: /dev/tty", "");print}' > $log_screen_fast

    # take actual screenshot (image) 
    sudo screencap -p $screen_fast
    sudo chown $USER:$USER $screen_fast

    # logging 
    myprint "Done with screenshots: screen-log-fast-${curr_run_id}.txt -- screenshot-fast-${curr_run_id}.png"
	
	#close open tabs (not on Chrome)
	if [ $browser_package == "com.brave.browser" ] 
	then 
		ans=$(($num_tabs % 5))
		if [ $ans -eq 0 -a $curr_run_id -gt 0 ] 
		then 
			close_brave_tabs
		else 
			# closing Brave 
			close_all
		fi 
	fi 

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
        ext=`echo $filename | cut -f 2 -d "."`
        screen_fast_processed="${res_folder}/${prefix}_processed.${ext}"
		myprint "HERE-- Prefix:$prefix -- Suffix:$ext"
        if [ ! -f $screen_fast_processed ]
        then 
            echo "Image optimization to help OCR..."
            convert $screen_fast -type Grayscale "temp.${ext}"  
            convert "temp.${ext}" -gravity South -chop 0x240 $screen_fast_processed
            convert $screen_fast_processed -gravity North -chop 0x500 "temp.${ext}"  
            mv "temp.${ext}" $screen_fast_processed
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
}

# make sure the screen is ON
turn_device_on

# make sure SELinux is permissive
ans=`sudo getenforce`
if [ $ans == "Enforcing" ] 
then 
	myprint "Disabling SELinux"
	sudo setenforce 0
	sudo getenforce
fi 

# folder creation
suffix=`date +%d-%m-%Y`
curr_run_id=`date +%s`
res_folder="./speedtest-results/$suffix"
mkdir -p $res_folder 
screen_fast="${res_folder}/screenshot-fast-${curr_run_id}.png"
log_screen_fast="${res_folder}/screen-log-fast-${curr_run_id}.txt"
run_speed_test

# all good 
echo "DONE :-)"
