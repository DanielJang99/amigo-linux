#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11-4-2023
## NOTE: Script that automates Samsung SmartThings to track SmartTags 

generate_post_data(){
  cat <<EOF
    {
    "uid":"${uid}",
    "timestamp":"${curr_time}",
    "msg":"SMARTTAG_ERROR"
    }
EOF
}

util_file=`pwd`"/util.cfg"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

NUM_TAGS=20
SERVER_PORT=8083
uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
# open SmartThings and navigate to devices map 
turn_device_on
sleep 2
close_all

if sudo [ -f ".track_smarttag" ];then
    to_run=`cat .track_smarttag`
else 
    echo "true" > ".track_smarttag"
    to_run="true"
fi

su -c monkey -p com.samsung.android.oneconnect 1 > /dev/null 2>&1
sleep 3
sudo input tap 550 2130 
sleep 3
sudo input tap 480 990 
sleep 5

while [ "$to_run" == "true" ]
do 

    # Navigate to the first smarttag device in "My Devices"
    sudo input tap 980 1580
    sleep 2 
    sudo input tap 500 500
    sleep 2 

    today=`date +%d-%m-%Y`
    smart_tag_log_dir="smarttag_logs/${today}"
    if [ ! -d "$smart_tag_log_dir" ];then 
        mkdir -p $smart_tag_log_dir
    fi
    curr_hour=`date +%H`
    # output_file="${smart_tag_log_dir}/smarttag_log_${curr_hour}.txt"
    output_file="${smart_tag_log_dir}/smarttag_log.txt"

    for((i=0; i<NUM_TAGS; i++))
    do
        sudo input tap 650 2005
        sleep 3
        sudo input keyevent KEYCODE_HOME
        sleep 1 
        su -c cp /data/data/com.samsung.android.oneconnect/shared_prefs/FME_SELECTED_DEVICE.xml /data/data/com.termux/files/home/mobile-testbed/src/termux
        su -c chmod 755 FME_SELECTED_DEVICE.xml
        SMARTTHINGS_DEVICE=`cat FME_SELECTED_DEVICE.xml | grep "SELECTED_FME_INFO"`
        curr_time=`date +\%m-\%d-\%y_\%H:\%M:\%S`
        echo "$curr_time" >> $output_file
        python v2/parse_smarttags_info.py "$SMARTTHINGS_DEVICE" >> $output_file 
        cur_tag=`tail -n 1 $output_file | awk '{print $4}'`
        if [[ "$last_tag" == "$cur_tag" ]]; then
            close_all
            timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/smarttag
            exit 1
        fi
        last_tag=$cur_tag
        sudo input keyevent KEYCODE_APP_SWITCH
        sleep 1 
        sudo input tap 550 1000
        sleep 1 
        sudo input swipe 800 1860 300 1860
        sleep 1
    done
    to_run=`cat .track_smarttag`
done

close_all 
turn_device_off