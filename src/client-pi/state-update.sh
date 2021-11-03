#!/bin/bash
## NOTE: report updates to the central server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "uid":"${uid}",
    "wifi_connection": "${wifi}", 
    "usb_tethering":"${usbTethering}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}"
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

# check current space usage
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`

# check CPU usage 
prev_total=0
prev_idle=0
result=`cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
prev_idle=`echo "$result" | cut -f 2`
prev_total=`echo "$result" | cut -f 3`
sleep 3 
result=`cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`

# check memory usage
mem_info=`free -m | grep Mem | awk '{print "Total:"$2"\tUsed:"$3"\tFree:"$4"\tAvailable:"$NF}'`

# report data back to control server
#echo "$(generate_post_data)" 
curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
