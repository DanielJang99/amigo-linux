#!/data/data/com.termux/files/usr/bin/bash
## Author: Matteo Varvello 
## Date:   11/10/2021

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file 

echo "toggle_wifi off"
toggle_wifi "off"
timeout 5 /usr/bin/ifconfig wlan0 > wlan-info 2>&1
echo $?
sleep 5 
echo "toggle_wifi on"
toggle_wifi "on"
