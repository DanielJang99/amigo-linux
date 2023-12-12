#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: update Kenzo app if necessary  
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11/30/2023

adb_file=`pwd`"/adb-utils.sh"
source $adb_file

update_required="false"
setup_dir="/data/data/com.termux/files/home/mobile-testbed/src/setup/APKs"
kenzo_latest_file="${setup_dir}/.kenzo_latest"  # timestamp of latest Kenzo update, fetched from server
if [ ! -f $kenzo_latest_file ];then
    exit 0
fi
kenzo_latest_update=`cat $kenzo_latest_file`

kenzo_local_file="${setup_dir}/.kenzo_local"    # timestamp of the last time Kenzo was updated locally on the device
if [ ! -f $kenzo_local_file ];then
    myprint "Kenzo will update as we do not know when it was last updated"
    update_required="true"
else
    kenzo_local_update=`cat $kenzo_local_file`
    if [[ "$kenzo_local_update" != "$kenzo_latest_update" ]];then
        myprint "Kenzo will update. Server ts: $kenzo_latest_update Local ts: $kenzo_local_update"
        update_required="true"
    fi
fi

if [[ $update_required == "true" ]];then
    kenzo_pkg="com.example.sensorexample"
    apk="app-debug.apk"

    # cache folder to save kenzo files until time of update
    mkdir -p kenzo_cache
    mkdir -p kenzo_location_cache
    su -c cp -R /storage/emulated/0/Android/data/com.example.sensorexample/files/. kenzo_cache/
    su -c cp -R /data/data/com.example.sensorexample/files/. kenzo_location_cache/
    sudo pm uninstall $kenzo_pkg
    sudo pm install -t "${setup_dir}/$apk"
    sudo pm grant $kenzo_pkg android.permission.ACCESS_FINE_LOCATION
    sudo pm grant $kenzo_pkg android.permission.READ_PHONE_STATE
    sudo pm grant $kenzo_pkg android.permission.BLUETOOTH_SCAN
    sudo pm grant $kenzo_pkg android.permission.BLUETOOTH_CONNECT
    sudo pm grant $kenzo_pkg android.permission.ACCESS_BACKGROUND_LOCATION
    sleep 2
    su -c echo "$kenzo_latest_update" > $kenzo_local_file
    turn_device_on
    su -c monkey -p $kenzo_pkg 1 > /dev/null 2>&1
    sleep 2 
    sudo input tap 550 1920
    sleep 1 
    close_all
    turn_device_off
    su -c cp -R ./kenzo_cache/. /storage/emulated/0/Android/data/com.example.sensorexample/files/
    sudo rm -r kenzo_cache 
    su -c chmod -R 777 /storage/emulated/0/Android/data/com.example.sensorexample/files/*.txt
    su -c cp -R ./kenzo_location_cache/. /data/data/com.example.sensorexample/files/
    sudo rm -r kenzo_location_cache 
    su -c chmod -R 777 /data/data/com.example.sensorexample/files/*.csv
else
    myprint "No need to update Kenzo"
fi


