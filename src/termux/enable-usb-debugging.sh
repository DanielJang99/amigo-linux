#!/data/data/com.termux/files/usr/bin/env bash

# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
opt="enable"
if [ $# -eq 1 ] 
then
	opt="disable"
fi 
sleep_time=5


if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# turn device on and clean all 
turn_device_on
close_all

# launch settings 
echo "Launching settings..."
sudo am start -n com.android.settings/com.android.settings.SubSettings
sleep $sleep_time
echo "Swiping down..."
sudo input swipe 300 1000 300 300
sleep $sleep_time
echo "Entering SYSTEM..."
sudo input tap 370 1075
sleep $sleep_time
echo "Entering developer options..."
sudo input tap 370 755
sleep $sleep_time
echo "Swiping down..."
sudo input swipe 300 1000 300 300
sleep $sleep_time
echo "Clicking enable USB debugging..."
sudo input tap 370 1010
sleep $sleep_time

if [ $opt == "enable" ] 
then 
	echo "Clicking confirm..."
	sudo input tap 580 835
	sleep $sleep_time
fi 
close_all
turn_device_off
