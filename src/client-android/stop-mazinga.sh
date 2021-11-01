#!/bin/bash
package="com.example.sensorexample"
for device_id in `adb devices | grep device | grep -v attached | awk '{print $1}'`
do
	adb -s $device_id shell am force-stop $package
done
