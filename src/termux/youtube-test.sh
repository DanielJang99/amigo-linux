#!/bin/bash
## NOTE: testing getting <<stats for nerds>> on youtube
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

# lower all the volumes
sudo media volume --show --stream 3 --set 5  # media volume
sudo media volume --show --stream 1 --set 5	 # ring volume
# Q: alarm volume? 

# make sure screen is ON
turn_device_on

# launch YouTube 
am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=TSZxxqHoLzE"
sleep 1

# switch between portrait and landscape
# ?? 

# activate stats for nerds  
# Q: how to know if off or not? 
#tap_screen 680 105 1 
#tap_screen 370 1125 

# collect data 
t_s=`date +%s`
t_p=`date +%s`
let "t_p = t_s - t_e"
while [ $t_p -gt $DURATION ] 
do 
	# click to copy clipboard 
	tap_screen 592 216 1

	# dump clipboard 
	termux-clipboard-get
	t_p=`date +%s`
	let "t_p = t_s - t_e"
	sleep 1 
done

# turn device off when done
turn_device_on
