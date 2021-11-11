#!/data/data/com.termux/files/usr/bin/bash
## Author: Matteo Varvello 
## Date:   11/10/2021

sudo input keyevent KEYCODE_HOME
echo "[toggle_wifi] swipe down"
sudo input swipe 370 0 370 500
sleep 5
echo "[toggle_wifi] press"
sudo input tap 300 100
sleep 2 
echo "[toggle_wifi] swipe up"
sudo input swipe 370 500 370 0

#toggle_wifi "off"
#timeout 5 /usr/bin/ifconfig wlan0 > wlan-info 2>&1
#echo $?
#sleep 5 
#toggle_wifi "on"
