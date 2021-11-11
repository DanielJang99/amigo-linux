#!/data/data/com.termux/files/usr/bin/bash
## Notes: Collection of abd utils 
## Author: Matteo Varvello (Brave Software) 
## Date: 02/04/2019

# common parameters
DEBUG=1
screen_brightness=70     # default screen brightness

# import common file
common_file=`pwd`"/common.sh"
if [ -f $common_file ]
then
	source $common_file
else
	echo "Common file $common_file is missing"
	exit -1
fi

# simply tap the screen 
tap_screen(){
	if [ $# -lt 2 ]
	then 
		myprint "[tap_screen] missing <x,y> coordindates"
		exit -1
	fi 
    x=$1
    y=$2
    t_comm=1
    if [ $# -eq 3 ]
    then
    	t_comm=$3
    fi 
    sudo input tap $x $y
    sleep $t_comm
}

# emulate user interaction with a page
page_interact(){
    s_time=`date +%s`
    duration=$1
    num_down=4
    num_up=2
    t_p=0
    myprint "interaction with page start: $s_time"
    while [ $t_p -lt $duration ]
    do
        for((i=0; i<num_down; i++))
        do
            #scroll down
            swipe "down" $width $height
            t_current=`date +%s`
            let "t_p = t_current - s_time"
            if [ $t_p -ge $duration ]
            then
                break
            fi
            sleep 5
        done
        for((i=0; i<num_up; i++))
        do
            #scroll up
            swipe "up" $width $height
            t_current=`date +%s`
            let "t_p = t_current - s_time"
            if [ $t_p -ge $duration ]
            then
                break
            fi
            sleep 5
        done
    done

    # logging
    e_time=`date +%s`
    let "time_passed = e_time - s_time"
    let "ts = e_time - t_start_sync"
    myprint "[INFO] Interaction with page end: $e_time. Interaction-duration: $time_passed"
}


# swipe up or down 
swipe(){
	movement=$1
	width=$2
	height=$3
	t1=`date +%s`
	let "x_coord = width/2"
	if [ $movement == "down" ] 
	then 
		let "start_y = height/2"
		#end_y=100
		end_y=300
	elif [ $movement == "up" ] 
	then 
		#start_y=100
		start_y=300
		let "end_y = height/2"
	else 
		myprint "ERROR - Option requested ($1) is not supported"
	fi 
	
	# execute the swipe 
	sudo input swipe $x_coord $start_y $x_coord $end_y

	# log duration
	t2=`date +%s`
	let "tp = t2 - t1"
	myprint "[INFO] Scrolling $movement. Duration: $tp"
}

#make sure device is ON 
turn_device_on(){	
	is_on="false"
	num_tries=0
	max_attempts=5
	ans=-1
	
	while [ $is_on == "false" -a $num_tries -lt $max_attempts ]
	do
		sudo dumpsys window | grep "mAwake=false"
		if [ $? -eq 0 ]
		then
			myprint "Screen was OFF. Turning ON (Attempt $num_tries/$max_attempts)"
			sudo input keyevent KEYCODE_POWER
		else
			myprint "Screen is ON. Nothing to do!"
			is_on="true"
			ans=0
		fi
		let "num_tries++"
	done

	# return status 
	return $ans
}

# turn device off 
turn_device_off(){	
	sudo dumpsys window | grep "mAwake=false"
	if [ $? -eq 0 ]
	then
		myprint "Screen was OFF. Nothing to do" 
	else
		sleep 2 
		myprint "Screen is ON. Turning off"
		sudo input keyevent KEYCODE_POWER
	fi
}

# accept cookies fo websites under test
accept_cookies(){
	myprint "Attempt accepting cookies for $1"
	if [ $device_id == "LGH870eb6286bb" -o $device_id == "LGH870b714ee1b" ] 
	then 
		if [ $1 == "https://www.bbc.com/" ] 
		then 
			tap_screen 700 2300 1 
			tap_screen 300 2600 1 
		elif [ $1 == "https://elpais.com" ] 
		then 
			tap_screen 700 1720
		elif [ $1 == "https://www.cnn.com" ] 
		then 
			adb -s $device_id shell input swipe 500 1000 300 300 #FIXME
			tap_screen 700 2500	
		else 
			tap_screen 700 2500	
		fi 
	elif [ $device_id == "e1afce790502" ] 
	then 
		if [ $1 == "https://www.bbc.com/" ] 
		then 
			tap_screen 550 1800 1 
			tap_screen 250 2020 1 
		elif [ $1 == "https://elpais.com" ] 
		then 
			tap_screen 550 1155
		elif [ $1 == "https://www.cnn.com" ] 
		then 
			tap_screen 550 2090
		else 
			tap_screen 550 1974	
		fi
	fi 
}

# needed unless I can fix the other thign
chrome_onboarding(){
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -f 2 -d "/" | sed s/"}"// | awk -F '.' '{print $NF}'`
	if [ $curr_activity == "FirstRunActivity" ]
	then 
		tap_screen 370 1210 1
		tap_screen 370 1210 1
		tap_screen 600 1200 1
		tap_screen 600 1200 1
	else 
		myprint "No onboarding was detected"
	fi 
} 


# helper to do Brave onboarding
brave_onboarding(){
	curr_activity=`sudo dumpsys window windows | grep -E 'mCurrentFocus' | cut -f 2 -d "/" | sed s/"}"// | awk -F '.' '{print $NF}'`
	if [ $curr_activity == "P3aOnboardingActivity" ]
	then 
		tap_screen 370 1100 1
		tap_screen 370 1200 1
		tap_screen 370 1200 1
		tap_screen 664 508 1
	else 
		myprint "No onboarding was detected"
	fi 
}

# helper to close opened brave tabs
close_brave_tabs(){
	myprint "Closing Brave tabs"
	am start -n $browser_package/$browser_activity -d "brave://about"
	tap_screen 506 1230 1
	tap_screen 640 1230 1
	tap_screen 370 1048 1
}

# helper to init fast.com (seems to be crashing)
init_fast_com(){
	myprint "Init fast.com"
	am start -n $browser_package/$browser_activity -d "https://fast.com"
	sleep 30 
	#tap_screen 370 830 1
}

# turn wifi on or off
toggle_wifi(){
	opt=$1
	wifiStatus="off"
	ifconfig wlan0 | grep inet | grep "\." > /dev/null
	if [ $? -eq 0 ] 
	then 
		wifiStatus="on"
	fi 
	if [ $opt == "on" ] 
	then 
 		if [ $wifiStatus == "off" ] 
		then 
			sudo input swipe 370 0 370 500
			tap_screen 300 100
			sudo input swipe 370 500 370 0
		else 
			myprint "Requested wifi ON and it is already ON"
		fi 
	elif [ $opt == "off" ] 
		if [ $wifiStatus == "on" ] 
		then 
			sudo input swipe 370 0 370 500
			tap_screen 300 100
			sudo input swipe 370 500 370 0
		else 
			myprint "Requested wifi OFF and it is already OFF"
		fi 
	else 
		myprint "Option $opt not supported (on/off)"
	fi 
}


# close all pending applications 
close_all(){
	# logging 
	dev_model=`getprop ro.product.model | sed s/" "//g`
	myprint "[CLOSE_ALL] Closing all pending applications for device: $dev_model"

	# go HOME 
	sudo input keyevent KEYCODE_HOME

	# enter switch application tab 
	sudo input keyevent KEYCODE_APP_SWITCH
	sleep 2

	# press close all 
	tap_screen 370 1210 

	# go back HOME 
	#sudo input keyevent KEYCODE_HOME
}

# setup phone priot to an experiment 
phone_setup_simple(){
	# disable notification 
	myprint "[INFO] Disabling notifications for the experiment"
	settings put global heads_up_notifications_enabled 0

	# set desired brightness
	myprint "[INFO] Setting screen brightness to $screen_brightness -- ASSUMPTION: no automatic control" 
	settings put system screen_brightness $screen_brightness

	#get and log some useful info
	dev_model=`getprop ro.product.model | sed s/" "//g` # S9: SM-G960U
	android_vrs=`getprop ro.build.version.release`
	myprint "[INFO] DEV-MODEL: $dev_model ANDROID-VRS: $android_vrs"	

	# remove screen timeout 
	max_screen_timeout="2147483647"
	#max_screen_timeout="2147460000"
	settings put system screen_off_timeout $max_screen_timeout

	# close all pending applications
	close_all

	# all good 
	return 0 
}
