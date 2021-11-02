#!/bin/bash
# read input 
if [ $# -ne 2 ] 
then 
	echo "USAGE: $0 adb-device-id option [start/stop]"
	exit -1 
fi 
device_id=$1
opt=$2

# check for errors 
if [ $opt != "start" -a $opt != "stop" ] 
then 
	echo "Opt $opt not supported. Supported options: [start/stop]"
	exit -1 
fi

#check current status and compare with user request 
ifconfig | grep "usb0" > /dev/null
isTethering=$?
if [ $isTethering -eq 0 -a $opt == "start" ] 
then 
	echo "Nothing to do. Requested tethering, already active"
	exit -1 
fi 
if [ $isTethering -eq 1 -a $opt == "stop" ] 
then 
	echo "Nothing to do. Requested to stop tethering, already stopped"
	exit -1 
fi 

# (de)activate tethering
echo  "(De)activate USB tethering..."
adb -s $1 shell am start -n com.android.settings/.TetherSettings > /dev/null 
sleep 2 
adb -s $1 shell input tap 650 245 > /dev/null 
#adb -s $1 shell input tap 925 1700 #OLD: why not working?
sleep 5
adb -s $1 shell "input keyevent KEYCODE_HOME" > /dev/null

# give some time 
echo "Done. Time to check..."

#make sure USB tethering is active
if [ $opt == "start" ] 
then 
	# wait for USB ready
	echo  "Waiting for USB interface..."
	ifconfig | grep "usb0" > /dev/null
	status=$?
	attempt=0
	while [ $status -ne 0 ] 
	do
		let "attempt++"
		if [ $attempt -ge 5 ] 
		then 
			break
		fi 
		sleep 5 
		ifconfig | grep "usb0" > /dev/null
		status=$?
	done
	if [ $status -eq 0 ] 
	then 
		echo  "USB interface found! Testing USB tethering (after 5 sec sleep)..."
		sleep 5 
		#sleep 5 
		ip=`timeout 10 curl -s --interface usb0 ifconfig.me`
		echo "External IP on USB interfaceL: $ip"
	else 
		echo "Something seems wrong. USB interface is not ready..."
	fi 
elif [ $opt == "stop" ] 
then
	# wait for USB gone
	echo  "Waiting for USB interface to be down..."
	ifconfig | grep "usb0" > /dev/null
	status=$?
	attempt=0
	while [ $status -ne 1 ] 
	do
		let "attempt++"
		if [ $attempt -ge 5 ] 
		then 
			echo "WARNING: usb interface is still up"
			break
		fi 
		sleep 5 
		ifconfig | grep "usb0" > /dev/null
		status=$?
	done
	if [ $attempt -lt 5 ] 
	then 
		echo "All good!"
	fi 
fi 
