#!/bin/bash
echo "Pushing apk to phone..."
adb push app-debug.apk /data/local/tmp/
echo "Removing previous version..."
adb uninstall com.example.sensorexample
echo "Installing new version..."
adb shell pm install -t /data/local/tmp/app-debug.apk
echo "Cleaning SD card...."
adb shell pm clear com.example.sensorexample
#adb -s $2 push $1 /data/local/tmp/
#apk_file=`echo $1 | awk -F "/" '{print $NF}'`
#echo $apk_file
#adb -s $2 shell pm install -t /data/local/tmp/$apk_file
