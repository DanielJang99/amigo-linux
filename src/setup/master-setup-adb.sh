#!/bin/bash
for device in `adb devices | grep -v List | cut -f 1 `
do 
	echo "./setup-phone-adb.sh $device > logs/log-adb-setup-$device"
	(./setup-phone-adb.sh $device > logs/log-adb-setup-$device 2>&1 &)
done
