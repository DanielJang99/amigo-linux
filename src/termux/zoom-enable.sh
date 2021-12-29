#!/data/data/com.termux/files/usr/bin/env bash
## Note:   Script to automate videoconferencing clients
## Author: Matteo Varvello
## Date:   11/29/2021

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	safe_stop
	exit -1 
}


# import utilities files needed
DEBUG=1
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# find package and verify videconferencing app is installed 
find_package(){
    if [ $app == "zoom" ]
    then 
        package="us.zoom.videomeetings"
    elif [ $app == "webex" ]
    then 
        package="com.cisco.webex.meetings"        
    elif [ $app == "meet" ]
    then 
        package="com.google.android.apps.meetings"        
    else 
        myprint "$app is currently not supported"
        exit -1
    fi 

    # make sure app is installed? 
    pm list packages -f | grep $package > /dev/null 
    if [ $? -ne 0 ] 
    then 
        myprint "Something is wrong. Package $package was not found. Please install it" 
        exit -1
    else 
		myprint "Package $package correctly found!"
	fi 
}

# grant permission required by each app
## adb shell dumpsys package com.cisco.webex.meetings | grep permission
grant_permission(){
    if [ $app == "zoom" ]
    then 
        sudo pm grant $package android.permission.RECORD_AUDIO
        sudo pm grant $package android.permission.WRITE_EXTERNAL_STORAGE
        sudo pm grant $package android.permission.CAMERA
    elif [ $app == "webex" ]
    then 
        sudo pm grant $package android.permission.RECORD_AUDIO
        sudo pm grant $package android.permission.WRITE_EXTERNAL_STORAGE
        sudo pm grant $package android.permission.CAMERA
        sudo pm grant $package android.permission.READ_CONTACTS
        sudo pm grant $package android.permission.CALL_PHONE
        sudo pm grant $package android.permission.ACCESS_FINE_LOCATION
    elif [ $app == "meet" ]
    then 
        sudo pm grant $package android.permission.RECORD_AUDIO
        sudo pm grant $package android.permission.CAMERA        
        sudo pm grant $package android.permission.CALL_PHONE
    fi 
}


# wait for a specific screen id (only zoom for now)  
wait_for_screen(){
	status="failed"
	screen_name=$1
	MAX_ATTEMPTS=10

	# logging 
	myprint "Wait for activity: $screen_name"

	# check current activity
	foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f2 | awk -F "." '{print $NF}' | sed 's/}//g'`
	#echo "==> $foreground"	 
	while [ $foreground != $screen_name ]
	do 
		let "c++"
		sleep 2 
		foreground=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f2 | awk -F "." '{print $NF}' | sed 's/}//g'`
		#echo "==> $foreground"
		if [ $c -eq $MAX_ATTEMPTS ]
		then
			myprint "Window $screen_name never loaded. Returning an error"
			exit -1 			
		fi 
		
		# testing -- check that device is on 
		turn_device_on
	done
	status="success" #FIXME -- manage unsuccess 
	sleep 2 	
}

# script usage
usage(){
    echo "========================================================================"
    echo "USAGE: $0 -a/--app, -p/--pass, -m/--meet, -c/--clear, -i/--id"
    echo "========================================================================"    
    echo "-a/--app        videoconf app to use: zoom, meet, webex" 
    echo "-p/--pass       zoom meeting password" 
    echo "-m/--meet       zoom meeting identifier" 
    echo "-c/--clear      clear zoom state (enable flag, default=false)" 
    echo "-i/--id         test identifier to be used" 
    echo "--suffix        folder identifier for results" 
    echo "========================================================================"
    exit -1
}

# general parameters
clear_state="false"                      # clear zoom state before the run 
use_video="false" 	                     # flag to control video usage or not 
package=""                               # package of videoconferencing app to be tested
duration=10                              # default test duration before leaving the call
phone_info=$base_dir"/phones-info.json"  # json file containing device information 
suffix=`date +%d-%m-%Y`                  # folder id (one folder per day)
test_id=`date +%s`                       # unique test identifier 
pcap_collect="false"                     # flag to control pcap collection ar router
iface="wlan0"                            # current default interface where to collect data
use_monsoon="false"                      # flag to control monsoon usage or not (battery measurements)
remote="false"                           # start a remote client in Azure 
use_vpn="false"                          # flag to control if to use a VPN or not
video_recording="false"                  # record screen or not 
change_view="false"                      # change from default view 
turn_off="false"                         # turn off the screen 
big_packet="false"                       # keep track if big packet size was passed 
use_mute="false"                         # FIXME 
uid="none"                               # user ID
sync_time=0                              # future sync time 
cpu_usage_middle="N/A"                   # CPU measured in the middle of a test 
report="true"                            # scp data back to the server
screenshots="false"                      # should take screenshots or not 

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        -a | --app)
            shift; app="$1"; shift;
            ;;
        -p | --pass)
            shift; password="$1"; shift;
            ;;
        -m | --meet)
            shift; meeting_id="$1"; shift;
            ;;
        -h | --help)
            usage
            ;;
	    -c | --clear)
            shift; clear_state="true";
            ;;
        -i | --id)
            shift; test_id="$1"; shift;
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# lock this device 
touch ".locked"

# make sure screen is in portrait 
myprint "Ensuring that screen is in portrait and auto-rotation disabled"
sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
sudo  settings put system user_rotation 0          # put in portrait

# screen info
width="720"
height="1280"
let "x_center = width/2"
let "y_center = height/2"

# check that app is supported and find its package 
find_package

# folder organization
res_folder="./videoconferencing/${suffix}"
mkdir -p $res_folder 

# make sure screen is on
turn_device_on

# allow permission
grant_permission

# close all pending apps
close_all

# start video recording
id=`date +%s`
t_start=`date +%s`
screen_video="zoom-recording-${id}.mp4"
(sudo screenrecord $screen_video --time-limit 80 &)
myprint "Started screen recording on file: $screen_video"

# start app 
t_launch=`date +%s` 
myprint "Launching $app..."
sudo monkey -p $package 1 > /dev/null 2>&1

# allow time for app to launch 
sleep 5 

# needed to handle warning of zoom on rooted devices (even if not clear) 
wait_for_screen "LauncherActivity"	
myprint "Accepting warning due to rooted phone..."
sudo input tap 435 832
 
# click on "join a meeting"
wait_for_screen "WelcomeActivity"
tap_screen $x_center 1020 5
 
# enter meeting ID
wait_for_screen "JoinConfActivity"
sudo input text "$meeting_id" 
tap_screen $x_center 655 5

# enter password if needed
wait_for_screen "ConfActivityNormal"
sleep 5 
if [ -z $password ]
then 
	myprint "Password not provided. Verify on screen if needed or not" 
else 
	myprint "Entering Password: $password" 
	sudo input text "$password" 
	sleep 2
	tap_screen 530 535 1
fi 

# allow page to load
myprint "Allow next page to load. No activity name, just sleep 10 seconds"
sleep 10 

# potentially click accept term 
myprint "Click accept terms..."
tap_screen 530 860 

# see if time to upload video
t_now=`date +%s`
let "t_left = 65 - (t_now - t_start)"
if [ $t_left -gt 0 ]
then 
	myprint "Wait for video to be done... (sleep $t_left)"
	sleep $t_left 
	myprint "Uploading file $screen_video"
	sudo chown $USER:$USER $screen_video
	(timeout 60 scp -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no $screen_video root@23.235.205.53: > /dev/null 2>&1 &)
fi 

# close all and turn off screen 
close_all
turn_device_off
clean_file ".locked"