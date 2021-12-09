#!/data/data/com.termux/files/usr/bin/env bash

# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
opt="enable"
if [ $# -eq 1 ] 
then
	opt="disable"
fi 

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


close_all

sudo am start -n com.android.settings/com.android.settings.SubSettings
sleep 2 
sudo input swipe 300 1000 300 300
sleep 2 
sudo input tap 370 1075
sleep 2 
sudo input tap 370 755
sleep 2 
sudo input swipe 300 1000 300 300
sleep 2 
sudo input tap 370 1010
sleep 2 

if [ $opt == "enable" ] 
then 
	sudo input tap 580 835
fi 
close_all
