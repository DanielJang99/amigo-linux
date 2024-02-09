#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: Run short net-tests specifically for Airalo  
## Author: Daniel Jang 
## Date: 2/9/2024

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

 
network_type=`get_network_type`
if [[ "$network_type" != *"airalo"* ]]
then
    myprint "check network type"
    exit 1 
fi 

if [[ "$network_type" != *"true"* ]]
then 
    myprint "check internet connectivity"
    exit 1 
fi 

linkPropertiesFile="/storage/emulated/0/Android/data/com.example.sensorexample/files/linkProperties.txt"
def_iface=`su -c cat "$linkPropertiesFile" | cut -f 2 -d " " | head -n 1`
if [[ "$def_iface" != *"rmnet"* ]]
then 
    myprint "check default interface"
    exit 1 
fi

today=`date +\%d-\%m-\%y`
output_path="logs/$today"
mkdir -p $output_path
current_time=`date +%s`
suffix=`date +%d-%m-%Y`

(./v2/net-testing.sh $suffix $current_time $def_iface "short" | timeout 1500 cat > $output_path/net-testing-short-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 & )