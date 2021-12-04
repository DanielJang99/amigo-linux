#!/bin/bash


#for device in `adb devices | grep -v List | cut -f 1 `
#do 
#	echo "./setup-phone-adb.sh $device > logs/log-$device"
#	(./setup-phone-adb.sh $device > logs/log-adb-setup-$device 2>&1 &)
#done

device="44aaf2df7d16"
(./setup-phone-adb.sh $device > logs/log-adb-setup-$device 2>&1 &)
device="9e1996117d56"
(./setup-phone-adb.sh $device > logs/log-adb-setup-$device 2>&1 &)
device="c959d34f7d56"
(./setup-phone-adb.sh $device > logs/log-adb-setup-$device 2>&1 &)
