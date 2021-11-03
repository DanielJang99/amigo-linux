#!/bin/bash
## Master script for constant experiments on the mobile testbed
## Author: Matteo Varvelo
## Date: 11/01/2021

# import util file
script_dir=`pwd`
DEBUG=1
util_file=`pwd`"/client-android/util.cfg"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# script usage
usage(){
    echo "============================================================"
    echo "USAGE: $0 --dur, --pi, --debug"
    echo "============================================================"
    echo "--dur      how long to run"
    echo "--pi       run on pi even if on wifi"
    echo "--debug    turn on debug mode (do not use on flight)"
    echo "============================================================"
    exit -1
}


# close all pending applications 
close_all(){
	# logging 
	dev_model=`adb -s $device_id shell getprop ro.product.model | sed s/" "//g`
	myprint "[CLOSE_ALL] Closing all pending applications for device: $dev_model"

	# go HOME
	adb -s $device_id shell "input keyevent KEYCODE_HOME"
	
	# enter switch application tab
	adb -s $device_id shell "input keyevent KEYCODE_APP_SWITCH"
	sleep 2
	if [ $dev_model == "LG-H870" ] 
	then 
		adb -s $device_id shell "input tap 770 2500"
	elif [ $dev_model == "M2004J19C" ] 
	then
		adb -s $device_id shell "input tap 540 2080"
	elif [ $dev_model == "DRA-L21" ] 
	then 
		adb -s $device_id shell "input tap 355 1260"
	else 
		myprint "[WARNING] Closing of pending apps is not supported yet for model $dev_model"
	fi 
	
	# go back HOME 
	myprint "[CLOSE_ALL] Pressing HOME"
	adb -s $device_id shell "input keyevent KEYCODE_HOME"
}


# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    myprint "Trapped CTRL-C"
    safe_stop
    myprint "EXIT!"
    exit -1
}

# kill a target process via a keyword
my_kill(){
	for pid in `ps aux | grep $1 | grep -v grep | awk '{print $2}'`
	do 
		if [ $# -eq 2 ] 
		then 
			kill -SIGINT $pid 
		else 
			kill -9 $pid
		fi 
	done
}

# make sure nothing is running
safe_stop(){
	sudo killall tcpdump > /dev/null 2>&1
	my_kill "ping.sh"
	my_kill "cdn-test.sh"
	my_kill "speed-browse-test.sh"
	#my_kill "quic-test.sh"
	my_kill "fiat_client.py"
	my_kill "quic-test-external.sh"

	# stop kenzo in background on each phone 
	for device_id in "${list_devices[@]}"
	do
		myprint "Resetting kenzo on device: $device_id"
		adb -s $device_id shell pm grant $kenzo android.permission.WRITE_EXTERNAL_STORAGE
		adb -s $device_id shell pm grant $kenzo android.permission.READ_PHONE_STATE
		adb -s $device_id shell pm grant $kenzo android.permission.ACCESS_FINE_LOCATION
		adb -s $device_id shell "am force-stop com.android.chrome"
		adb -s $device_id shell monkey -p $kenzo 1 > /dev/null 2>&1
		sleep 2 
		x_coord=${xCoords[$device_id]}
		y_coord=${yCoords[$device_id]}
		if [ $device_id != "BRE9K18610909502" ] 
		then
			let "x_coord += 500"
		else 
			let "x_coord += 400"
		fi 
		#myprint "TESTING => Device: $device_id x_coord:$x_coord y_coord:$y_coord"
		adb -s $device_id shell "input tap $x_coord $y_coord"	
		sleep 1 
		adb -s $device_id shell "am force-stop $kenzo"

  		# close all pending apps
		close_all
	done
}

# prepare phone for a test 
phone_setup(){
	# disable notification
	myprint "[INFO] Disabling notifications for the experiment"
	adb -s $device_id shell settings put global heads_up_notifications_enabled 0

	# set desired brightness
	#screen_brightness=70  
	#myprint "[INFO] Setting screen brightness to $screen_brightness -- ASSUMPTION: no automatic control"
	#adb -s $device_id shell settings put system screen_brightness $screen_brightness

	#get and log some useful info
	dev_model=`adb -s $device_id shell getprop ro.product.model | sed s/" "//g` # S9: SM-G960U
	android_vrs=`adb -s $device_id shell getprop ro.build.version.release`
	myprint "[INFO] DEV-MODEL: $dev_model ANDROID-VRS: $android_vrs"

	# remove screen timeout
	max_screen_timeout="2147483647"
	#max_screen_timeout="2147460000"
	adb -s $device_id shell settings put system screen_off_timeout $max_screen_timeout

	# close all pending applications
	#close_all

	# all good
	return 0
}


# process to handle pi experiments 
run_pi(){
	cd client-pi
	(./ping.sh $test_id > $log_dir/"ping-log.txt" 2>&1 &)
	(./cdn-test.sh $test_id > $log_dir/"cdn-log.txt" 2>&1 &)
	#(./quic-test.sh  --start --id $test_id > $log_dir/"quic-myserver-log.txt" 2>&1 &) # this is to our server
	(./quic-test-external.sh --id $test_id > $log_dir/"quic-external-log.txt" 2>&1 &)
	cd $script_dir	
}

# process to handle android experiments 
run_android(){
	cd client-android
	for device_id in "${list_devices[@]}"
	do
		if [ $device_id == "BRE9K18610909502" ] 
		then 
			myprint "Skipping huawei ($device_id). Running only mazinga/kenzo"
			continue
		fi 
		deviceName=${deviceNames[$device_id]} 
		#if [ $device_id == "e1afce790502" ] 
		#then 
		#	opt=" -d $deviceName --id $test_id"
		#else 
		#	opt=" -d $deviceName --id $test_id --novideo"
		#fi 
		opt=" -d $deviceName --id $test_id"
		(./speed-browse-test.sh $opt > "${log_dir}/speed-browse-${device_id}.txt" 2>&1 & )
	done
}

# dump telephony data via dumpsys 
dump_telephony(){
	t_s=`date +%s` 
	t_last_dump=`date +%s` 
	t_p=0
	while [ $t_p -lt $duration ] 
	do  
		for device_id in "${list_devices[@]}"
		do
			log_tel="${log_dir}/telephony-${device_id}.txt"
			date +%s >> $log_tel
			adb -s $device_id shell dumpsys telephony.registry | grep -i mSignalStrength >> $log_tel
		done
		t_c=`date +%s`
		let "t_p = t_c - t_s"
		sleep 5
		let "t_dump = t_c - t_last_dump"
		if [ $t_dump -gt 900 ] # dumping logs each 15 minutes
		then 
			for device_id in "${list_devices[@]}"
			do
				if [ $device_id == "e1afce790502" ] # this device creates insanely large logs (300MB in 5 minutes)
				then 
					continue
				fi 
				myprint "Saving logcat from $device_id..."
				adb -s $device_id logcat -d >> $log_dir"/logcat-$device_id"
				adb -s $device_id logcat -c
			done
			t_last_dump=`date +%s`
		fi
	done
}

#make sure device is ON
turn_device_on(){
    is_on="false"
    num_tries=0
    max_attempts=5
    ans=-1

    while [ $is_on == "false" -a $num_tries -lt $max_attempts ]
    do
        adb -s $device_id shell dumpsys window | grep "mAwake=false"
        #adb -s $device_id shell dumpsys window | grep mAwake=false > /dev/null
        if [ $? -eq 0 ]
        then
            myprint "Screen was OFF. Turning ON (Attempt $num_tries/$max_attempts)"
            adb -s $device_id shell "input keyevent KEYCODE_POWER"
			if [ $device_id == "e1afce790502" ]
			then
				myprint "Attempting unlocking $device_id"
				adb -s e1afce790502 shell input swipe 200 500 200 0
			fi 
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

# check wifi 
check_wifi(){
	adb -s $device_ide shell dumpsys connectivity | grep "WIFI" | grep "CONNECTED"
}

# input parameters 
iface="usb0"                        # pi interface for tethering
test_id=`date +%s`                  # unique test identifier 
duration=600                        # experiment duration 
log_dir=`pwd`"/logs/"$test_id       # folder where logs should go 
kenzo="com.example.sensorexample"   # name of mazinga/kenzo app
iot_proxy="nj.batterylab.dev"       # address of iot proxy
iot_port="7352"                     # port to be used
run_pi="false"                      # flag to force pi tests also if on wifi               
connected="false"                   # flag to know if pi is connected via mobile
isDebugging="false"                 # flag to control if debugging mode or not                   

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        -h | --help)
            usage
            ;;
        --dur)
            shift; duration="$1"; shift;
      		;;
        --pi)
            shift; run_pi="true"
      		;;
        --debug)
            shift; isDebugging="true"
      		;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# report on free space 
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`
myprint "Current free space is: $free_space GB" 

# make sure ADB is ready and  get list of devices 
declare -gA yCoords
declare -gA xCoords
declare -gA deviceNames
ps aux | grep adb | grep server
if [ $? -ne 0 ] 
then 
	myprint "Restarting ADB..."
	adb devices
	sleep 5 
fi 
adb devices | grep -v "attached" | grep "device" > ".devices"
c=0
while read line
do 
	device_id=`echo "$line" | awk '{print $1}'`
	list_devices[c]=$device_id
	let "c++"
	# ASSUMPTION: only REDMI-GO are connected 
	# coordinates needed to start kenzo (per device) -- FIXME 
	xCoords["e1afce790502"]=332
	yCoords["e1afce790502"]=1166
	deviceNames["e1afce790502"]="M2004J19C" 
done < ".devices"

# make sure devices are on
for device_id in "${list_devices[@]}"
do
	turn_device_on
done

# stop things unless debugging
if [ $isDebugging == "false" ] 
then 
	# make sure no virtual screen is running
	myprint "Stopping potential VNC/scrcpy/noVNC"
	./android/stop.sh > /dev/null
	
	#update time
	myprint "NTP update using 0.es.pool.ntp.or"
	sudo ntpdate 0.es.pool.ntp.org
fi 

# folder organization
mkdir -p $log_dir

# phone preparation for test
for device_id in "${list_devices[@]}"
do
	# prepare phone
	phone_setup

	# clean logcat and make sure size is right
	adb -s $device_id logcat -c 
	adb -s $device_id logcat -G 100M 
done

# logging
myprint "TestID: $test_id"

# start tcpdump 
#/usr/sbin/ifconfig | grep $iface > /dev/null
#if [ $? -eq 1 ] 
#then 
#	myprint "WARNING - skipping tcpdump since $iface is not available"
#else 
#	#myprint "Running tcpdump on interface $iface"
#	myprint "WARNING - skipping tcpdump because of potentiallt too much traffic"
#	connected="true"
#	#(sudo tcpdump -i $iface -w $log_dir/$test_id.pcap > /dev/null 2>&1 &)
#fi 

# clean potential pending things
myprint "Clean potential pending things"
safe_stop

# start kenzo in background on each phone 
#for device_id in "${list_devices[@]}"
#do
#	#echo $device_id
#	adb -s $device_id shell monkey -p $kenzo 1 > /dev/null 2>&1
#	sleep 5
#	x_coord=${xCoords[$device_id]}
#	y_coord=${yCoords[$device_id]}
#	#myprint "TESTING => Device: $device_id x_coord:$x_coord y_coord:$y_coord"
#	adb -s $device_id shell "input tap $x_coord $y_coord"	
#
#	# take screenshot
#	adb -s $device_id exec-out screencap -p > $log_dir/"kenzo-screen-"$device_id".png"
#done

# start pi experiments 
if [ $connected == "true" -o $run_pi == "true" ] 
then 
	myprint "Running <<run_pi>> process" 
	run_pi &
fi 

# start Android experiments 
myprint "Skipping Android experiments for now"
#myprint "Running <<run_android>> process" 
#run_android &

# wait for experiment to be done #TODO: could use some other signal to stop 
#myprint "Running test for: $duration seconds"
#dump_telephony #Testing dumping telephony data each 5 secs until duration 
#sleep $duration 

# stop all running 
safe_stop

# pull data 
#for device_id in "${list_devices[@]}"
#do
#	myprint "Saving logcat from $device_id..."
#	adb -s $device_id logcat -d >> $log_dir"/logcat-$device_id"
#	myprint "Pulling mazinga files from $device_id..."
#	fname=`adb -s $device_id shell "ls /storage/emulated/0/Android/data/com.example.sensorexample/files" | grep mazinga | tail -n 1` 
#	adb -s $device_id pull /storage/emulated/0/Android/data/com.example.sensorexample/files/$fname $log_dir
#	fname=`adb -s $device_id shell "ls /storage/emulated/0/Android/data/com.example.sensorexample/files" | grep sensor | tail -n 1` 
#	adb -s $device_id pull /storage/emulated/0/Android/data/com.example.sensorexample/files/$fname $log_dir
#done

# report on free space 
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`
myprint "Current free space is: $free_space" 
