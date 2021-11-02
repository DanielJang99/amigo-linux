#!/bin/bash

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "uid":"${uid}",
    "wifi_connection": "${wifi}", 
    "usb_tethering":"${usbTethering}"
    }
EOF
}

# FIXME
uid="1234"

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
#echo "$(generate_post_data)" 
curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
