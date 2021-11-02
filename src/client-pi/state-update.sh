#!/bin/bash


# check for wifi 
wifi="False"
ifconfig | grep "wlan0" > /dev/null
status=$?
if [ $status -eq 0 ]
then
    wifi="True"
fi 


# check for USB tethering
usbTethering="False"
ifconfig | grep "usb0" > /dev/null
status=$?
if [ $status -eq 0 ]
then
    usbTethering="True"
fi 
    
# report data back to control server
curl -H "Content-Type: application/json" --data '{"wifi":$wifi, "usbTethering":$usbTethering}' https://mobile.batterylab.dev:8082/status
