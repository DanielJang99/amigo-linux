#!/bin/bash
## NOTE: testing getting <<stats for nerds>> on youtube
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

# activate stats for nerds  
activate_stats_nerds(){
	echo "Activating stats for nerds!!"
	tap_screen 680 105 
	tap_screen 680 105  
	tap_screen 370 1125
}

# script usage
usage(){
    echo "================================================================================"
    echo "USAGE: $0 --load, --novideo"
    echo "================================================================================"
    echo "--load       Page load max duration"
    echo "--iface      Network interface in use"
    echo "--novideo    Turn off video recording"
    echo "================================================================================"
    exit -1
}

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

# default parameters
DURATION=30                        # experiment duration
interface="wlan0"                  # default network interface to monitor (for traffic)
suffix=`date +%d-%m-%Y`            # folder id (one folder per day)
curr_run_id=`date +%s`             # unique id per run

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        --dur)
            shift; DURATION="$1"; shift;
            ;;
        --iface)
            shift; interface="$1"; shift;
            ;;
        --suffix)
            shift; suffix="$1"; shift;
            ;;
        --id)
            shift; curr_run_id="$1"; shift;
            ;;
        -h | --help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# folder creation
res_folder="./youtube-results/$suffix"
mkdir -p $res_folder
log_file="${res_folder}/youtube-${curr_run_id}.txt"

# cleanup the clipboard
termux-clipboard-set "none"

# lower all the volumes
myprint "Making sure volume is off"
sudo media volume --stream 3 --set 0  # media volume
sudo media volume --stream 1 --set 0	 # ring volume
sudo media volume --stream 4 --set 0	 # alarm volume

# make sure screen is ON
turn_device_on

# clean youtube state  
myprint "Cleaning YT state"
sudo pm clear com.google.android.youtube

# re-enable stats for nerds for the app
myprint "Enabling stats for nerds and no autoplay"
sudo monkey -p com.google.android.youtube 1
sleep 10  # can take a while to load when cleaned...
sudo input tap 665 100
sleep 1 
sudo input tap 370 1180
sleep 1 
sudo input tap 370 304
sleep 1 
sudo input tap 370 230 
sleep 1 
sudo input keyevent KEYCODE_BACK
sleep 1
sudo input tap 370 200
sleep 1 
sudo input swipe 370 500 370 100
sleep 1 
sudo input tap 370 1250

#launch test video
am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=TSZxxqHoLzE"

# make sure stats for nerds are active
myprint "Make sure stats for nerds are active"
ready="false"
while [ $ready == "false" ]
do 
	termux-clipboard-get > ".clipboard"
	cat ".clipboard" | grep "cplayer"
	if [ $? -ne 0 ] 
	then 		
		activate_stats_nerds
		tap_screen 592 216 1
		termux-clipboard-get > ".clipboard"
		cat ".clipboard" | grep "cplayer" > /dev/null 2>&1
		if [ $? -eq 0 ] 
		then
			ready="true"		
			echo "Ready to start!!"
			cat ".clipboard" > $log_file
			echo "" >> $log_file
		fi
	else
		ready="true"		
		echo "Ready to start!!"
	fi
done

# switch between portrait and landscape
# ?? 

# collect data 
myprint "Collect data for $DURATION seconds..."
t_s=`date +%s`
t_e=`date +%s`
let "t_p = t_s - t_e"
while [ $t_p -lt $DURATION ] 
do 
	# click to copy clipboard 
	tap_screen 592 216 1

	# dump clipboard 
	termux-clipboard-get >> $log_file
	echo "" >> $log_file

	# update on time passed 
	sleep 1 
	t_e=`date +%s`
	let "t_p = t_e - t_s"
	#echo "TimePassed: $t_p"
done

# stop playing 
myprint "Stop playing!"
sudo input keyevent KEYCODE_BACK
sleep 2 
tap_screen 670 1130 1 

# go HOME
sudo input keyevent KEYCODE_HOME

# turn device off when done
turn_device_on
