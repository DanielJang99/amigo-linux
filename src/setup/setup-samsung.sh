#!/bin/bash
# NOTE: script to prepare a phone (REDMI-GO) for the mobile testbed
# Author: Matteo Varvello (varvello@gmail.com)
# Date: 11/19/2021

# Before running, make sure that on Developer Options: 
# 1) enable [Stay Awake]
# 2) disable [Verify apps over USB]

# check input 
if [ $# -ne 1 -a $# -ne 2 ] 
then
    echo "================================================================"
    echo "USAGE: $0 adb-device-id [production]"
    echo "================================================================"
    exit -1 
fi 

# close all pending applications
close_all(){
    # go HOME
    sudo input keyevent KEYCODE_HOME

    # enter switch application tab
    sudo input keyevent KEYCODE_APP_SWITCH
    sleep 2

    # press close all
    tap_screen 370 1210
}

# install an app using google playstore
install_app_playstore(){
	# read input 
	if [ $# -ne 2 ] 
	then 
		echo "ERROR. Missing params to install_app_playstore"
		exit -1 
	fi 
	package=$1
	name=$2
    adb -s $device_id shell 'pm list packages -f' | grep -w $package > /dev/null
    if [ $? -ne 0 ]
    then	
        echo "Installing app $name ($package)"
		if [ $first == "true" ] 
		then 
			adb -s $device_id shell monkey -p com.android.vending 1 > /dev/null 2>&1
			sleep 20
			first="false"
		fi 
        adb -s $device_id shell "input tap 340 100"
        adb -s $device_id shell input text "$name"
        adb -s $device_id shell "input tap 665 1225"
        sleep 5
        adb -s $device_id shell "input tap 545 610"
        #adb -s $device_id shell "input tap 600 250"
        sleep 5
        adb -s $device_id shell "input tap 58 105"
        sleep 3
    else
        echo "App $name ($package) already installed"
    fi
}

# helper to insall apk via ADB
install_simple(){
	# read input 
	if [ $# -ne 2 ] 
	then 
		echo "ERROR. Missing params to install_via_fdroid"
		exit -1 
	fi
	pkg=$1
	apk=$2
	echo "[install_simple] $pkg"
	adb -s $device_id shell 'pm list packages -f' | grep -w $pkg > /dev/null
	to_install=$?
	if [ $to_install -eq 1 ]
	then 
		./install-app.sh $device_id $apk
	else
		echo "$pkg is already installed"
	fi 
}

# helper to install apk via fdroid 
install_via_fdroid(){
	TIMEOUT=120
	# read input 
	if [ $# -ne 2 ] 
	then 
		echo "ERROR. Missing params to install_via_fdroid"
		exit -1 
	fi 
	pkg=$1
	name=$2
	adb -s $device_id shell "input keyevent KEYCODE_HOME"	
	adb -s $device_id shell input keyevent 111
	adb -s $device_id shell 'pm list packages -f' | grep $pkg > /dev/null
	to_install=$?
	sleep 2 
	if [ $to_install -eq 1 ]
	then 
		adb -s $device_id logcat -c 
		adb -s $device_id shell monkey -p $fdroid_pack 1 > /dev/null 2>&1
		sleep 5 
		adb -s $device_id shell dumpsys window windows | grep -E 'mCurrentFocus' | grep "AppListActivity" > /dev/null
		if [ $? -ne 0 ] 
		then 
			adb -s $device_id shell "input tap 630 1080"
			sleep 1 
		fi 
		adb -s $device_id  shell input text "$name"
		sleep 10 
		adb -s $device_id shell "input keyevent KEYCODE_ENTER"
		adb -s $device_id shell "input tap 626 256"
		adb -s $device_id shell input keyevent 111
		sleep 10
		last_time=`adb -s $device_id  logcat -d | grep "Package enqueue rate" | tail -n 1 | awk '{print $2}'`
		prev_time=0
		if [ ! -z $last_time ] 
		then 
			while [ $prev_time != $last_time ] 
			do
				#echo "$prev_time -- $last_time" 
				prev_time=$last_time 
				sleep 10
				last_time=`adb -s $device_id  logcat -d | grep "Package enqueue rate" | tail -n 1 | awk '{print $2}'`
			done 
		fi 
		echo "Download completed!"
		adb -s $device_id shell "input tap 626 256"
		sleep 5 
		if [ $first_run == "true" ] 
		then 
			adb -s $device_id shell "input tap 560 780"
			sleep 1 
		    adb -s $device_id shell "input tap 640 400"
			sleep 1 
		    adb -s $device_id shell "input keyevent KEYCODE_BACK"
			sleep 1 
			first_run="false"
		fi 
		adb -s $device_id shell "input tap 620 1210" 
		echo "Waiting for installation to complete...."
		to_install=1
		t_s=`date +%s`
		while [ $to_install -eq 1 ]
		do 
			t_c=`date +%s`
			let "t_p = t_c - t_s"
			if [ $t_p -gt $TIMEOUT ] 
			then 
				echo "ERROR installing $name"
				exit -1 
			fi 
			adb -s $device_id shell 'pm list packages -f' | grep $pkg > /dev/null
			to_install=$?
			sleep 5 
		done 
		echo "$name ($pkg) was installed correctly"
		adb -s $device_id shell "input tap 590 130"
	else 
		echo "$name ($pkg) is already installed. Nothing to do!"
	fi 
}

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
use_fdroid="false"                # control how to intall termux stuff 
full_setup="true"                 # flag to control if to redo command inside termux (enable SSH, etc)

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


# always make sure screen is in portrait
#adb -s $device_id shell "content insert --uri content://settings/system --bind name:s:accelerometer_rotation --bind value:i:0"
#adb -s $device_id shell "content insert --uri content://settings/system --bind name:s:user_rotation --bind value:i:0"

# verify phone is on wifi
adb -s $device_id shell dumpsys netstats > .data
wifi_iface=`cat .data | grep "iface" | head -n 1 | cut -f 2 -d "=" | cut -f 1 -d " "`
if [ ! -z $wifi_iface ]
then 
    wifi_ip=`adb -s  $device_id shell ifconfig $wifi_iface | grep "\." | grep -v packets | awk '{print $2}' | cut -f 2 -d ":"`
	echo "Device connceted on WiFi ($wifi_iface) with IP $wifi_ip"
else 
    echo "ERROR. Phone $device_id is not on wifi"
    exit -1 
fi 

# install Fdroid
if [ $use_fdroid == "true" ] 
then
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
		adb -s $device_id push $apk /data/local/tmp/ > /dev/null 2>&1
		adb -s $device_id shell pm install -t /data/local/tmp/$apk
		sleep 2 
		adb -s $device_id shell 'pm list packages -f' | grep $fdroid_pack > /dev/null
		to_install=$?
		if [ $to_install -eq 1 ]
		then 
			echo "ERROR installing $apk"
			exit -1
		else 
			echo "$apk ($fdroid_pack) was installed correctly"
			adb -s $device_id shell monkey -p $fdroid_pack 1 > /dev/null 2>&1
			echo "Allowing 2 minutes for Fdroid repositories to update...."
			sleep 240
		fi 
	else 
		echo "$apk ($fdroid_pack) is already installed" 
	fi 
fi 

# install termux, termux-api, termux-boot
if [ $use_fdroid == "true" ] 
then 
	#first_run="true"  #FIXME: needs a better way to intercept "allow" (maybe fdroid setting?)
	first_run="false"
	install_via_fdroid $termux_pack "termux\ terminal\ emulator"
	install_via_fdroid $termux_api "termux\ api"
	install_via_fdroid $termux_boot "termux\ boot"
else 
	cd APKs
	install_simple $termux_pack "com.termux_117.apk"     #https://f-droid.org/repo/com.termux_117.apk
	install_simple $termux_api "com.termux.api_49.apk"	 #https://f-droid.org/repo/com.termux.api_49.apk
	install_simple $termux_boot "com.termux.boot_7.apk"  #https://f-droid.org/repo/com.termux.boot_7.apk
	cd - > /dev/null 2>&1
fi 


# make sure nmap is installed 
hash nmap
if [ $? -ne 0 ] 
then 
	echo "Installing nmap since missing" 
	sudo apt install -y nmap
fi 

###### testing changing repo  UNRELIABLE (maybe need a double click?)
#adb -s $device_id shell input text "termux-change-repo"
#adb -s $device_id shell "input keyevent KEYCODE_ENTER"
#sleep 2
#adb -s $device_id shell "input tap 230 420"
#sleep 2 
#adb -s $device_id shell "input tap 230 530"
#echo "Wait for packages updates..."
#sleep 15 
###### testing

# set default password
if [ $full_setup == "true" ] 
then 
	# prepping inside termux
	echo "Setting up SSH (plus code updates)"
	adb -s $device_id push install.sh /sdcard/	
	adb -s $device_id shell "input keyevent KEYCODE_HOME"	
	adb -s $device_id shell input keyevent 111
	adb -s $device_id shell monkey -p com.termux 1 > /dev/null 2>&1
	echo "Wait for termux bootstrapping to be done..."
	sleep 10

    echo "Package update"
    adb -s $device_id shell input text "apt\ update\ -y"
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    sleep 20

    adb -s $device_id shell input text "apt\ upgrade\ -y"
    adb -s $device_id shell "input keyevent KEYCODE_ENTER"
    sleep 70

	echo "Setting default password: $password"
	adb -s $device_id shell input text "pkg\ install\ -y\ termux-auth"
	sleep 1
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 10 
	adb -s $device_id shell input text "passwd"
	sleep 1
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2
	adb -s $device_id shell input text "$password"
	sleep 1 
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 
	adb -s $device_id shell input text "$password"
	sleep 1 
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 

	# install sudo 
	adb -s $device_id shell input text "pkg\ install\ -y\ tsu"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	echo "Allowing 30 secs to install sudo"
	sleep 20 

	# enable permissive selinux
	adb -s $device_id shell input text "sudo\ setenforce\ \0"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 5 

	# enable and run install.sh 
	echo "Preparing to run <<install.sh>>"
	adb -s $device_id shell input text "sudo\ mv\ /\sdcard/\install.sh\ ./"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 
	adb -s $device_id shell input text "sudo\ chmod\ +x\ install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 
	adb -s $device_id shell input text "USER=\\\`whoami\\\`"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 
	adb -s $device_id shell input text "sudo\ chown\ \\\$USER\ install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 2 
	adb -s $device_id shell input text ".\/install.sh"
	adb -s $device_id shell "input keyevent KEYCODE_ENTER"
	sleep 40  # watch out cause it is not blocking (ADB gets out) 
fi 

# wait for above process to be done
SSH_TIMEOUT=120
echo "Wait $SSH_TIMEOUT sec to see if SSH PORT (8022) becomes reachable...."
ssh_ready="false"
ts=`date +%s`
while [ $ssh_ready == "false" ] 
do 
	tc=`date +%s`
	let "tp = tc - ts"
	sudo nmap -p 8022 $wifi_ip | grep "closed"
	if [ $? -ne 0 ] 
	then 
		ssh_ready="true"
	fi 
	if [ $tp -gt $SSH_TIMEOUT ] 
	then 
		echo "ERROR! Timeout ($TIMEOUT sec) Something is wrong. SSH should be installed at this point"
		exit -1 
	fi 
	sleep 5 
done

# restart termux and enable crontab -- no need can be done via SSH
#adb -s $device_id shell input text "exit"
#adb -s $device_id shell "input keyevent KEYCODE_ENTER"
#sleep 2
#adb -s $device_id shell monkey -p com.termux 1 > /dev/null 2>&1
#sleep 3
#adb -s $device_id shell input text "sv-enable\ crond"
#adb -s $device_id shell "input keyevent KEYCODE_ENTER"
#sleep 1 
#adb -s $device_id shell "input keyevent KEYCODE_HOME"

# test SSH 
c=0
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "pwd"
ans=$?
while [ $ans -ne 0 ] 
do 
	echo "Issue with SSH..."
	sleep 5 
	sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "pwd"
	ans=$?
	let "c++"
	if [ $c -eq 5 ] 
	then 
		echo "SSH-ERROR. Aborting!"
		exit -1 
	fi 
done 
echo "SSH test was succesful!" 

# install local packages 
hash jq
if [ $? -ne 0 ] 
then 
	echo "Installing json parser (jq) since missing"
	sudo apt-get install jq
fi 
hash sshpass
if [ $? -ne 0 ] 
then 
	echo "Installing sshpass since missing" 
	sudo apt install -y sshpass
fi 

# SSH preparation
echo "SSH prepping..."
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "mkdir -p .ssh"
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 $ssh_key $wifi_ip:.ssh 
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "authorized_keys" "config" $wifi_ip:.ssh 
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "bashrc" $wifi_ip:.bashrc
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "mkdir -p .termux/boot/"
sshpass -p "$password" scp -oStrictHostKeyChecking=no -P 8022 "start-sshd.sh" $wifi_ip:.termux/boot/
sshpass -p "$password" ssh -oStrictHostKeyChecking=no -p 8022 $wifi_ip "chmod +x .termux/boot/start-sshd.sh"

# launch termux-boot to make sure it is ready 
echo "launching termux-boot to make sure it is ready"
adb -s $device_id shell monkey -p $termux_boot 1 > /dev/null 2>&1
sleep 5 
adb -s $device_id shell "input keyevent KEYCODE_HOME"	

# disable youtube go and maps if there
adb -s $device_id shell 'pm list packages -f' | grep "com.google.android.apps.youtube.mango" > /dev/null
if [ $? -eq 0 ]
then
    echo "Disabling youtube-go since it conflicts with youtube" 
	adb -s $device_id shell 'pm disable-user --user 0 com.google.android.apps.youtube.mango'
fi
adb -s $device_id shell 'pm list packages -f' | grep "com.google.android.apps.mapslite" > /dev/null
if [ $? -eq 0 ]
then
    echo "Disabling maps-lite to avoid conflicts with maps" 
	adb -s $device_id shell 'pm disable-user --user 0 com.google.android.apps.mapslite'
fi

# install apps needed
package_list[0]="com.google.android.apps.maps"
package_list[1]="us.zoom.videomeetings"
package_list[2]="com.cisco.webex.meetings"
package_list[3]="com.google.android.apps.meetings"
package_list[4]="com.google.android.youtube"
package_list[5]="com.example.sensorexample"
package_list[6]="com.kiwibrowser.browser"
name_list[0]="google\ maps"
name_list[1]="zoom"
name_list[2]="webex"
name_list[3]="google\ meet"
name_list[4]="youtube"
name_list[5]="kenzo"
name_list[6]="Kiwi\ Browser"
apk_list[0]="com.google.android.apps.maps_11.7.5.apk"
apk_list[1]="us.zoom.videomeetings_5.8.4.2783.apk"
apk_list[2]="com.cisco.webex.meetings_41.11.0.apk"
apk_list[3]="com.google.android.apps.meetings_2021.10.31.apk"
apk_list[4]="com.google.android.youtube_16.46.35.apk"
apk_list[5]="app-debug.apk"
apk_list[6]="com.kiwibrowser.browser.apk"
num_apps="${#package_list[@]}"
first="true"
cd APKs
for((i=0; i<num_apps; i++))
do
    package=${package_list[$i]}
    name=${name_list[$i]}
	apk=${apk_list[$i]}
	install_simple $package $apk
	#install_app_playstore "$package" "$name"
done
cd - > /dev/null 2>&1
adb -s $device_id shell "input keyevent KEYCODE_HOME"

# clone code and run phone prepping script
echo "clone code and run phone prepping script"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pkg install -y git"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "git clone git@github.com:svarvel/mobile-testbed.git"
# ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pkg install python"
#ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "termux-notification -c \"ADB:$device_id\" --icon warning --prio high --vibrate pattern 500,500"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed && git init"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/setup && (./phone-prepping.sh &)"
if [ $production == "true" ] 
then 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"false\" > \"mobile-testbed/src/termux/.isDebug\"" 
else 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"true\" > \"mobile-testbed/src/termux/.isDebug\"" 
fi 

# wait for phone prepping to be done
echo "Wait for phone prepping to be done"
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

# setup cron jobs 
echo "Setting up CRON jobs..."
ssh -oStrictHostKeyChecking=no -t -i $ssh_key -p 8022 $wifi_ip 'sh -c "sv-enable crond"'
sleep 5 
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pidof crond"
if [ $? -ne 0 ]
then
	echo "ERROR Something went wrong!"
else
	echo "CRON is correctly running"
fi

IMEI=`adb -s $device_id shell "service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'"`
PHY_ID=`cat "./../termux/uid-list.txt" | grep $IMEI | head -n 1 | awk '{print $1}'`
if [ -z "$PHY_ID" ]
then
    PHY_ID=`tail -n 1 ./../termux/uid-list.txt | awk '{print $1}'`
    let "PHY_ID += 1"
    echo -e "$PHY_ID\t$IMEI" >> ./../termux/uid-list.txt
fi
echo -e "$PHY_ID\t$IMEI" > .uid
adb -s $device_id push .uid /sdcard/
adb -s $device_id shell su -c mv /sdcard/.uid /data/data/com.termux/files/home/mobile-testbed/src/termux
adb -s $device_id shell su -c chmod +r /data/data/com.termux/files/home/mobile-testbed/src/termux/.uid 

# logging 
echo "All good"


# additional steps that could not be automated with scripts 
# 1. Install "Boot Apps" from Play Store and add Termux & Termux:Boot
# 1.1 Turn off battery optimization for Boot Apps (could be necessary)
# 2. Install Kenzo Extension on Kiwi Browser 