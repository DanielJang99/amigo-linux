#!/data/data/com.termux/files/usr/bin/env bash

# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
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
sleep 1
sudo am start -n com.google.android.gms/com.google.android.gms.auth.uiflows.minutemaid.MinuteMaidActivity
sleep 10
sudo dumpsys window windows | grep -E 'mCurrentFocus' | grep MinuteMaidActivity
if [ $? -eq 0 ]
then
    echo "Authorization needed"
    sudo input tap 600 1200
    sleep 10
    sudo input text "Bremen2013"
    sleep 3
    sudo input keyevent KEYCODE_ENTER
    sleep 20
    sudo dumpsys window windows | grep -E 'mCurrentFocus' | grep MinuteMaidActivity
    if [ $? -eq 0 ]
    then
        echo "ERROR"
    else
        echo "ALL-GOOD"
    fi
else
    echo "Nothing to do"
fi
