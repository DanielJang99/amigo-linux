#!/bin/bash
# NOTE: script to prepare a phone (REDMI-GO) for the mobile testbed
# Author: Matteo Varvello (varvello@gmail.com)
# Date: 11/19/2021

# check input 
if [ $# -ne 1 ] 
then
    echo "============================="
    echo "USAGE: $0 adb-device-id"
    echo "============================="
    exit -1 
fi 

# parameters 
device_id=$1                     # device to be prepped 
ssh_key="id_rsa_mobile"          # unique key used for both SSH and GITHUB 
password="termux"                # default password

# install Fdroid
adb -s $device_id push F-Droid.apk /data/local/tmp/
adb -s $device_id shell pm install -t /data/local/tmp/F-Droid.apk

# install termux from FDroid
# need to activate install unknown apps 
adb -s $device_id shell monkey -p org.fdroid.fdroid 1
adb -s $device_id shell "input tap 630 1080"
adb -s $device_id shell input text "termux\ terminal\ emulator"
adb -s $device_id shell "input tap 626 256"
adb -s $device_id shell "input tap 560 780"
adb -s $device_id shell "input tap 640 400"
adb -s $device_id shell "input keyevent KEYCODE_BACK"
adb -s $device_id shell "input tap 620 1200"
adb -s $device_id shell "input tap 590 130"

# install boot and termux api
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
ip_add=`adb -s $device_id  shell "ifconfig wlan0" | grep "\." | grep -v packets | awk '{print $2}' | cut -f 2 -d ":"`

# SSH preparation
sudo apt install -y sshpass
sshpass -p "$password" ssh -p 8022 $ip_add "mkdir -p .ssh"
sshpass -p "$password" scp -P 8022 $key $ip_add:.ssh 
sshpass -p "$password" scp -P 8022 "authorized_keys" $ip_add:.ssh 
scp -i $key -P 8022 "config" $ip_add:.ssh

# clone code and run phone prepping scritp
ssh -i $key -p 8022 $ip_add "pkg install -y git"
ssh -i $key -p 8022 $ip_add "git clone git@github.com:svarvel/mobile-testbed.git"
ssh -i $key -p 8022 $ip_add "cd mobile-testbed/src/setup && ./phone-prepping.sh"