#!/bin/bash
for device_id in `adb devices | grep device | grep -v attached | awk '{print $1}'`
do
	adb -s $device_id uninstall "com.example.sensorexample"
	./install-app.sh apps/app-debug.apk $device_id
done
