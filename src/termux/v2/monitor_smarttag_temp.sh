#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11-4-2023
## NOTE: Temporary script to monitor one smart tag  

DEBUG=1
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

# open SmartThings and navigate to devices map 
turn_device_on
sleep 2
su -c monkey -p com.samsung.android.oneconnect 1 > /dev/null 2>&1
sleep 5 
sudo input tap 550 2130 
sleep 5
sudo input tap 480 990 
sleep 7

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
output_file="${smart_tag_log_dir}/smarttag_log_${curr_hour}.txt"
curr_time=`date +\%m-\%d-\%y_\%H:\%M:\%S`
echo "$curr_time" >> $output_file

sudo input tap 650 2005 
sleep 10
sudo input keyevent KEYCODE_HOME
sleep 1 
su -c cp /data/data/com.samsung.android.oneconnect/shared_prefs/FME_SELECTED_DEVICE.xml /data/data/com.termux/files/home/mobile-testbed/src/termux
su -c chmod 755 FME_SELECTED_DEVICE.xml
SMARTTHINGS_DEVICE=`cat FME_SELECTED_DEVICE.xml | grep "SELECTED_FME_INFO"`
python v2/parse_smarttags_info.py "$SMARTTHINGS_DEVICE" >> $output_file 
close_all
turn_device_off
