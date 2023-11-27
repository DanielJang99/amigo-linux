#!/data/data/com.termux/files/usr/bin/env bash

## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11/27/2023
## Note: Run Wehe test 

run_wehe(){
    turn_device_on
    su -c am start -n mobi.meddle.wehe/mobi.meddle.wehe.activity.MainActivity
    sleep 1 

    # prepare wehe test - toggle all tests 
    TOTAL_WEHE_TESTS=10
    while [ $TOTAL_WEHE_TESTS -gt 0 ];
    do
        su -c uiautomator dump /data/data/com.termux/files/home/mobile-testbed/src/termux/window_dump.xml
        toggle_btn_coords=`python ./v2/setup_wehe.py`
        tests_found=`echo "$toggle_btn_coords" | tail -n 1`
        let "TOTAL_WEHE_TESTS-=tests_found"
        num_buttons_to_toggle=`echo "$toggle_btn_coords" | wc -l`
        for((i=1;i<num_buttons_to_toggle;i++))
        do
            coord=`echo "$toggle_btn_coords" | head -n $i | tail -1`
            sudo input tap $coord
            sleep 0.5
        done
        sudo input swipe 500 1800 500 500
        sleep 1
    done
    myprint "Configured all tests. Now starting Differentiation Test"
    sudo input tap 550 2180
    sleep 1200 
    sudo input keyevent KEYCODE_HOME
    close_all
}

tap_wifi(){
    turn_device_on
    termux-brightness 0
    su -c cmd statusbar expand-settings
    sleep 1 
    sudo input tap 150 1500
    sudo input keyevent KEYCODE_APP_SWITCH
    sleep 1
    sudo input keyevent KEYCODE_BACK
    sleep 2
}


# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file


dev_model=`getprop ro.product.model | sed s/" "//g`
if [ $dev_model != "SM-G996B" ]
then
    myprint "Wehe test integration not yet supported on this model"
    exit 1
fi

# check if wehe test was conducted in the last 2 weeks  
current_time=`date +%s`
if [ -f ".wehe" ]
then
    TWO_WEEKS=1209600 
    last_wehe_time=`echo .wehe`
    let "t_since_last_wehe = current_time - last_wehe_time"
    if [ $t_since_last_wehe -lt $TWO_WEEKS ]
    then
        myprint "Wehe test was conducted recently"
        exit 0
    fi
fi

# check if there are sims on the device
subscriptions_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/subscriptions.txt"
if sudo [ ! -f $subscriptions_file ]; then
    myprint "No active subscriptions or sims"
    exit 0
fi
numSubs=`su -c cat $subscriptions_file | grep "sim" | wc -l`
if [ $numSubs -eq 0 ]
then
    exit 0
fi

# check if net-testing is running
while true; do 
    nettest_on=`ps aux | grep "net-testing.sh" | grep -v "grep" | grep -v "timeout" | wc -l`
    if [ $nettest_on -gt 0 ];
    then
        sleep 300
    else 
        break
    fi
done	

currentNetwork=`get_network_type`
while [[ "$currentNetwork" == "NONE"* ]];
do
    tap_wifi
    sleep 10
    currentNetwork=`get_network_type` 
done

# disable mobile data for wifi test  
turn_device_on
termux-brightness 0
su -c am start -n com.samsung.android.app.telephonyui/com.samsung.android.app.telephonyui.netsettings.ui.simcardmanager.SimCardMgrActivity
sleep 0.5 
sudo input swipe 500 1800 500 500
sleep 0.5 
sudo input tap 500 1760 
sleep 0.5
sudo input tap 200 2000 

while [[ "$currentNetwork" == "WIFI_false"* ]]
do
    sleep 1 
    currentNetwork=`get_network_type` 
done
run_wehe

sleep 2
tap_wifi  # disable wifi 
# re-enable data 
sleep 2
su -c am start -n com.samsung.android.app.telephonyui/com.samsung.android.app.telephonyui.netsettings.ui.simcardmanager.SimCardMgrActivity
sleep 0.5 
sudo input swipe 500 1800 500 500
sleep 0.5 
sudo input tap 500 1760 
sleep 0.5
sudo input tap 200 1760 

currentNetwork=`get_network_type`
iter=0 
while [[ "$currentNetwork" != "sim"* && "$currentNetwork" != *"true"* ]];
do 
    sleep 1
    currentNetwork=`get_network_type` 
    let "iter++"
    if [ $iter -gt 20 ];then
        myprint "Failed to get mobile data with internet connectivity"
        break
    fi
done

if [[ "$currentNetwork" == *"true" ]];
    run_wehe
fi
turn_device_off

today=`date +%d-%m-%Y`
wehe_log_dir="wehe_logs/${today}"
if [ ! -d "$wehe_log_dir" ];then
    mkdir -p $wehe_log_dir
fi

su -c cp /data/data/mobi.meddle.wehe/shared_prefs/ReplayActPrefsFile.xml /data/data/com.termux/files/home/mobile-testbed/src/termux
python ./v2/parse_wehe.py > "${wehe_log_dir}/output.txt"
echo "$current_time" > .wehe