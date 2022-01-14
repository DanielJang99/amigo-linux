#!/data/data/com.termux/files/usr/bin/env bash

#switch to 3G 
myprint "Switch to 3G"	
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
if [ -f "uid-list.txt" ] 
then 
	physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | cut -f 1`
fi 
myprint "UID: $uid PhysicalID: $physical_id"
turn_device_on
am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
sleep 5 

# enter 3G selection
tap_screen 370 765 5
tap_screen 370 765 5 

# take screenshot of network settings and upload to our server 
sudo screencap -p "network-setting-3G.png"
sudo chown $USER:$USER "network-setting-3G.png"
cwebp -q 80 "network-setting-3G.png" -o "network-setting-3G.webp" > /dev/null 2>&1 
if [ -f "network-setting-3G.webp" ]
then 
	chmod 644 "network-setting-3.webp"
	rm "network-setting-3G.png"
fi
remote_file="/root/mobile-testbed/src/server/network-settings/${physical_id}-3G.webp" 
(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no "network-setting-3G.webp" root@23.235.205.53:$remote_file > /dev/null 2>&1 &)

# select 3G and close all 
tap_screen 370 660 2
sudo input keyevent KEYCODE_BACK  
close_all
turn_device_off