#!/bin/bash
# NOTE: script to prepare a phone (REDMI-GO) for the mobile testbed
# Author: Matteo Varvello (varvello@gmail.com)
# Date: 11/19/2021

# check input 
if [ $# -ne 1 -a $# -ne 2 ] 
then
    echo "================================================================"
    echo "USAGE: $0 adb-device-id [production]"
    echo "================================================================"
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
production="false"                # default we are debugging 

# check if we want to switch to production
if [ $# -eq 2 ] 
then 
	echo "WARNING. Requested switching to production!"
	production="true"
fi 

# make sure phone is reachable via adb 
adb devices | grep $device_id > /dev/null 
if [ $? -eq 1 ] 
then 
	echo "ERROR. ADB identifier $device_id is not reachable"
	exit -1 
fi 
adb -s $device_id shell "input keyevent KEYCODE_HOME"	
adb -s $device_id shell input keyevent 111

# verify phone is on wifi
adb -s $device_id shell dumpsys netstats > .data
wifi_iface=`cat .data | grep "WIFI" | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
if [ ! -z $wifi_iface ]
then 
    wifi_ip=`adb -s  $device_id shell ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}' | cut -f 2 -d ":"`
	echo "Device connceted on WiFi ($wifi_iface) with IP $wifi_ip"
else 
    echo "ERROR. Phone $device_id is not on wifi"
    exit -1 
fi 

# install Fdroid
adb -s $device_id shell 'pm list packages -f' | grep $fdroid_pack > /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then
	echo "Starting Fdroid installation..." 
    if [ ! -f $apk ]
    then 
        echo "ERROR missing $apk"
        exit -1 
    fi 
    adb -s $device_id push $apk /data/local/tmp/
    adb -s $device_id shell pm install -t /data/local/tmp/$apk
    adb -s $device_id shell 'pm list packages -f' | grep $fdroid_pack > /dev/null
	to_install=$?
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing $apk"
        exit -1
    else 
        echo "$apk ($fdroid_pack) was installed correctly"
    fi 
else 
	echo "$apk ($fdroid_pack) is already installed" 
fi 

# install termux from FDroid
# need to activate install unknown apps 
adb -s $device_id shell 'pm list packages -f' | grep $termux_pack | grep -v $termux_boot | grep -v $termux_api > /dev/null
to_install=$?
if [ $to_install -eq 1 ]
then 
	# https://f-droid.org/repo/com.termux_117.apk
	echo "Starting termux installation via fdroid..." 
    adb -s $device_id shell monkey -p $fdroid_pack 1 > /dev/null 2>&1
	sleep 5 	
	echo "Allowing 2 minutes for Fdroid repositories to update...."
	sleep 240
	adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | grep "AppListActivity" > /dev/null
	if [ $? -ne 0 ] 
	then 
	    adb -s $device_id shell "input tap 630 1080"
		sleep 1 
	fi 
    adb -s $device_id shell input text "termux\ terminal\ emulator"
	sleep 10
    adb -s $device_id shell "input tap 626 256"
	echo "Allowing 5 mins for termux to download...."
	sleep 300
    adb -s $device_id shell "input tap 626 256"
	sleep 10 	
    adb -s $device_id shell "input tap 560 780"
	sleep 1 
    adb -s $device_id shell "input tap 640 400"
	sleep 1 
    adb -s $device_id shell "input keyevent KEYCODE_BACK"
	sleep 1 
    adb -s $device_id shell "input tap 620 1200"
	echo "Allowing 1 min to install termux...."
	sleep 60
    adb -s $device_id shell "input tap 590 130"
	adb -s $device_id shell 'pm list packages -f' | grep $termux_pack | grep -v $termux_boot | grep -v $termux_api > /dev/null
	to_install=$?
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux!"
        exit -1 
    else 
        echo "termux ($termux_pack) was installed correctly"
    fi
else 
	echo "termux ($termux_pack) is already installed"
fi 

# install termux api 
adb -s $device_id shell "input keyevent KEYCODE_HOME"	
adb -s $device_id shell input keyevent 111
adb -s $device_id shell 'pm list packages -f' | grep $termux_api> /dev/null
to_install=$?
sleep 2 
if [ $to_install -eq 1 ]
then 
    #https://f-droid.org/repo/com.termux.api_49.apk
	adb -s $device_id shell monkey -p $fdroid_pack 1 > /dev/null 2>&1
	sleep 5 
	adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | grep "AppListActivity" > /dev/null
	if [ $? -ne 0 ] 
	then 
    	adb -s $device_id shell "input tap 630 1080"
		sleep 1 
	fi 
    adb -s $device_id  shell input text "termux\ api"
    sleep 10 
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    adb -s $device_id shell "input tap 626 256"
	echo "Allowing 1 min for termux_api to download...."
	sleep 60
    adb -s $device_id shell "input tap 626 256"
    sleep 2 
	adb -s $device_id shell "input tap 620 1210" 
	echo "Allowing 30 sec min for termux_api to install..."
	sleep 30
    adb -s $device_id shell "input tap 590 130"
    adb -s $device_id shell 'pm list packages -f' | grep $termux_api > /dev/null
	to_install=$?
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux-api!"
        exit -1 
    else 
        echo "termux-api ($termux_api) was installed correctly"
    fi
else 
	echo "termux-api ($termux_api) is already installed"
fi 

# install termux boot 
adb -s $device_id shell "input keyevent KEYCODE_HOME"	
adb -s $device_id shell input keyevent 111
adb -s $device_id shell 'pm list packages -f' | grep $termux_boot> /dev/null
to_install=$?
sleep 2 
if [ $to_install -eq 1 ]
then 
	#org.fdroid.fdroid.installer.ApkFileProvider/files/TermuxBoot-0.7.apk
    echo "Installing termux-boot"
	adb -s $device_id shell monkey -p $fdroid_pack 1 > /dev/null 2>&1
	sleep 5 
	adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | grep "AppListActivity" > /dev/null
	if [ $? -ne 0 ] 
	then 
    	adb -s $device_id shell "input tap 630 1080"
		sleep 1 
    fi 
	adb -s $device_id  shell input text "termux\ boot"
    sleep 10 
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    adb -s $device_id shell "input tap 626 256"
	echo "Allowing 1 min for termux_boot to download...."
	sleep 60
    adb -s $device_id shell "input tap 626 256"
    sleep 2 
	adb -s $device_id shell "input tap 620 1210" 
	echo "Allowing 30 sec min for termux_boot to install..."
	sleep 30
    adb -s $device_id shell "input tap 590 130"
    adb -s $device_id shell 'pm list packages -f' | grep $termux_boot > /dev/null
	to_install=$?
    if [ $to_install -eq 1 ]
    then 
        echo "ERROR installing termux-boot!"
        exit -1 
    else 
        echo "termux-api ($termux_boot) was installed correctly"
    fi
else 
	echo "termux-boot ($termux_boot) is already installed"
fi  

# install SSH on termux (and update code) 
sudo nmap -p 8022 $wifi_ip | grep closed
if [ $? -eq 0 ] 
then 
	echo "Setting up SSH (plus code updated)"
	adb -s $device_id push install.sh /sdcard/	
	adb -s $device_id shell "input keyevent KEYCODE_HOME"	
	adb -s $device_id shell input keyevent 111
	adb -s $device_id shell monkey -p com.termux 1 > /dev/null 2>&1
	sleep 5 
	adb -s $device_id shell input text "pkg\ install\ -y\ tsu"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	echo "Allowing 30 secs to install sudo"
	sleep 30 
	adb -s $device_id shell input text "sudo\ setenforce\ \0"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 1 
	adb -s $device_id shell input text "sudo\ mv\ /\sdcard/\install.sh\ ./"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 1 
	adb -s $device_id shell input text "sudo\ chmod\ +x\ install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 1 
	adb -s $device_id shell input text "USER=\\\`whoami\\\`"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 1 
	adb -s $device_id shell input text "sudo\ chown\ \\\$USER\ install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 1 
	adb -s $device_id shell input text "sudo\ install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
else 
	echo "SSH already available -- assuming all rest was done  too" 
fi 

# set default password
echo "Setting default password: $password"
adb -s $device_id shell monkey -p com.termux 1 > /dev/null 2>&1
sleep 5 
adb -s $device_id shell input text "passwd"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"
adb -s $device_id shell input text "$password"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"
adb -s $device_id shell input text "$password"
adb -s $device_id shell "input keyevent KEYCODE_ENTER"

# SSH preparation
sudo nmap -p 8022 $wifi_ip | grep closed
if [ $? -eq 0 ] 
then 
	echo "ERROR! Something is wrong. SSH should be installed at this point"
	exit -1 
fi 
hash sshpass
if [ $? -ne 0 ] 
then 
	echo "Installing sshpass since missing" 
	sudo apt install -y sshpass
fi 
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "mkdir -p .ssh"
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 $ssh_key $wifi_ip:.ssh 
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "authorized_keys" "config" $wifi_ip:.ssh 
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "bashrc" $wifi_ip:.bashrc
echo "WARNING - check boot script from first phone"
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "mkdir -p .termux/boot/"
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "start-sshd.sh" $wifi_ip:.termux/boot/

# install apps needed
package_list[0]="com.google.android.apps.maps"
package_list[1]="com.google.android.youtube"
package_list[2]="com.google.android.apps.meetings"
package_list[3]="us.zoom.videomeetings"
package_list[4]="com.cisco.webex.meetings"
name_list[0]="google\ maps"
name_list[1]="youtube"
name_list[2]="google\ meet"
name_list[3]="zoom"
name_list[4]="webex"
num_apps="${#package_list[@]}"
first="true"
for((i=0; i<num_apps; i++))
do
    package=${package_list[$i]}
    name=${name_list[$i]}
    adb -s $device_id shell 'pm list packages -f' | grep -w $package > /dev/null
    if [ $? -ne 0 ]
    then
        echo "Installing app $name ($package)"
		if [ $first == "true" ] 
		then 
			adb -s $device_id shell monkey -p com.android.vending 1
			sleep 10
			first="false"
		fi 
        adb -s $device_id shell "input tap 340 100"
        adb -s $device_id shell input text "$name"
        adb -s $device_id shell "input tap 665 1225"
        sleep 5
        adb -s $device_id shell "input tap 600 250"
        sleep 5
        adb -s $device_id shell "input tap 58 105"
        sleep 1
    else
        echo "App $name ($package) already installed"
    fi
done
adb -s $device_id shell "input keyevent KEYCODE_HOME"

# clone code and run phone prepping script
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pkg install -y git"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "git clone git@github.com:svarvel/mobile-testbed.git"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/setup && (./phone-prepping.sh &)"
if [ $production == "true" ] 
then 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"false\" > \"mobile-testbed/src/termux/.isDebug\"" 
else 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"true\" > \"mobile-testbed/src/termux/.isDebug\"" 
fi 

# wait for phone prepping to be done
t_s=`date +%s`
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "ps aux | grep phone-prepping.sh | grep -v grep"
ans=$?
while [ $ans -eq 0 ] 
do 
	sleep 30
	t_c=`date +%s`
	let "t_p = t_c - t_s"
	echo "Waiting for prepping to be done. Time passed: $t_p sec"	
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "ps aux | grep phone-prepping.sh | grep -v grep"
	ans=$?
done
echo "All good"

# Q: can we run a test? 
