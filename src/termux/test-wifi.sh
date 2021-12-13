#!/data/data/com.termux/files/usr/bin/bash
## Author: Matteo Varvello 
## Date:   11/10/2021
## NOTE: script to test wifi toggling 

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file


close_all
echo "[$0] Turning wifi OFF"
toggle_wifi "off" "wlan0"
ifconfig wlan0 | grep inet | grep "\." > ".inet-info"
res=$?
echo "[$0] WLAN0 status: $res -- Detailed info:"
cat ".inet-info"
sleep 5 
echo "[$0] Turning wifi ON"
toggle_wifi "on" "wlan0"
ifconfig wlan0 | grep inet | grep "\." > ".inet-info"
res=$?
echo "[$0] WLAN0 status: $res -- Detailed info:"
cat ".inet-info"
