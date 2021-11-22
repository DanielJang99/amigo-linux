#!/bin/bash
# NOTE: script to prepare a phone (REDMI-GO) for the mobile testbed
# Author: Matteo Varvello (varvello@gmail.com)
# Date: 11/19/2021

# check input 
if [ $# -ne 1 ] 
then
    echo "==========================================="
    echo "USAGE: $0 adb-device-id"
    echo "==========================================="
    exit -1 
fi 

# parameters 
device_id=$1                      # device to be prepped 
ssh_key="id_rsa_mobile"           # unique key used for both SSH and GITHUB 
password="termux"                 # default password
apk="F-Droid.apk"                 # FDroid APK to be installed
fdroid_pack="org.fdroid.fdroid"   # fdroid package 
termux_pack="com.termux"          # termux package 
termux_boot="com.termux.boot"     # termux boot package 
termux_api="com.termux.api"       # termux API package 

# verify phone is on wifi
sudo dumpsys netstats > .data
wifi_iface=`cat .data | grep "WIFI" | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
if [ ! -z $wifi_iface ]
then 
    wifi_ip=`ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}'`
else 
    echo "ERROR. Phone $device_id is not on wifi"
    exit -1 
fi 

# install Fdroid
adb -s $device_id shell 'pm list packages -f' | grep $fdroid_pack > /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then 
    if [ ! -f $apk ]
    then 
        echo "ERROR missing $apk"
        exit -1 
    fi 
    adb -s $device_id push $apk /data/local/tmp/
    adb -s $device_id shell pm install -t /data/local/tmp/$apk
    adb -s $device_id shell 'pm list packages -f' | grep $fdroid_pack > /dev/null
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing $apk"
        exit -1
    else 
        echo "$apk ($fdroid_pack) was installed correctly"
    fi 
fi 
exit 0 

# install termux from FDroid
# need to activate install unknown apps 
adb -s $device_id shell 'pm list packages -f' | grep $termux_pack> /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then 
    adb -s $device_id shell monkey -p $fdroid_pack 1
    adb -s $device_id shell "input tap 630 1080"
    adb -s $device_id shell input text "termux\ terminal\ emulator"
    adb -s $device_id shell "input tap 626 256"
    adb -s $device_id shell "input tap 560 780"
    adb -s $device_id shell "input tap 640 400"
    adb -s $device_id shell "input keyevent KEYCODE_BACK"
    adb -s $device_id shell "input tap 620 1200"
    adb -s $device_id shell "input tap 590 130"
    adb -s $device_id shell 'pm list packages -f' | grep $termux_pack> /dev/null
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux!"
        exit -1 
    else 
        echo "termux ($termux_pack) was installed correctly"
    fi
fi 
exit 0 

# install termux api 
adb -s $device_id shell 'pm list packages -f' | grep $termux_api> /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then 
    adb -s $device_id shell monkey -p $fdroid_pack 1
    adb -s $device_id  shell input text "termux\ api"
    sleep 10 
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    adb -s $device_id shell "input tap 626 256"
    sleep 10 
    adb -s $device_id shell "input tap 626 256"
    sleep 2 
    adb -s $device_id shell "input tap 656 745"
    sleep 10 
    adb -s $device_id shell "input tap 590 130"
    adb -s $device_id shell 'pm list packages -f' | grep $termux_api > /dev/null
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux-api!"
        exit -1 
    else 
        echo "termux-api ($termux_api) was installed correctly"
    fi
fi 
exit 0 

# install termux boot 
adb -s $device_id shell 'pm list packages -f' | grep $termux_boot> /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then 
    adb -s $device_id  shell input text "termux\ boot"
    sleep 10 
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    adb -s $device_id shell "input tap 626 256"
    sleep 10 
    adb -s $device_id shell "input tap 626 256"
    sleep 2 
    adb -s $device_id shell "input tap 656 745"
    sleep 10 
    adb -s $device_id shell "input tap 590 130"
    adb -s $device_id shell "input keyevent KEYCODE_HOME"
    adb -s $device_id shell 'pm list packages -f' | grep $termux_boot > /dev/null
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux_boot!"
        exit -1 
    else 
        echo "termux-api ($termux_boot) was installed correctly"
    fi
fi 
exit 0 

# install SSH on termux (might indeed need human help)
adb -s $device_id shell monkey -p com.termux 1
adb -s device_id shell input text "apt\ update"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"
adb -s $device_id shell input text "apt\ upgrade"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"
adb -s $device_id  shell input text "pkg\ install\ -y\ openssh"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"

# set default password and find IP address (assume WLAN0)
adb -s $device_id shell monkey -p com.termux 1
adb -s $device_id shell input text "passwd"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"
adb -s $device_id  shell input text "$password"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"

# SSH preparation
sudo apt install -y sshpass
sshpass -p "$password" ssh -p 8022 $wifi_ip "mkdir -p .ssh"
sshpass -p "$password" scp -P 8022 $key $wifi_ip:.ssh 
sshpass -p "$password" scp -P 8022 "authorized_keys" $wifi_ip:.ssh 
scp -i $key -P 8022 "config" $wifi_ip:.ssh
scp -i $key -P 8022 "bashrc" $wifi_ip:.bashrc


# install apps needed -- TODO
adb -s $device_id monkey -p com.android.vending 1 
adb -s $device_id shell "input tap 340 100"
adb -s $device_id shell input text "google\ maps"
adb -s $device_id shell "input tap 665 1225"
adb -s $device_id shell "input tap 600 250"

adb -s $device_id shell "input tap 340 100"
adb -s $device_id shell input keyevent --longpress $(printf 'KEYCODE_DEL %.0s' {1..20})
adb -s $device_id shell input text "youtube"
adb -s $device_id shell "input tap 665 1225"
adb -s $device_id shell "input tap 600 250"
adb -s $device_id shell "input keyevent KEYCODE_HOME"


# googlemaps, chrome, youtube

# clone code and run phone prepping script
ssh -i $key -p 8022 $wifi_ip "pkg install -y git"
ssh -i $key -p 8022 $wifi_ip "git clone git@github.com:svarvel/mobile-testbed.git"
ssh -i $key -p 8022 $wifi_ip "cd mobile-testbed/src/setup && ./phone-prepping.sh"
ssh -i $key -p 8022 $wifi_ip "echo \"true\" > \"mobile-testbed/src/termux/.isDebug\""
#echo "false" > "mobile-testbed/src/termux/.isDebug"
