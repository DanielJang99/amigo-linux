#!/data/data/com.termux/files/usr/bin/bash
## Author: Matteo Varvello 
## Date:   11/10/2021

# import utilities files needed
#script_dir=`pwd`
#adb_file=$script_dir"/adb-utils.sh"
#source $adb_file 

# turn wifi on or off
toggle_wifi(){
    opt=$1
    myprint "[toggle_wifi] Requested: $opt"
    sudo input keyevent KEYCODE_HOME
    wifiStatus="off"
    /usr/bin/ifconfig wlan0 | grep "inet" | grep "\." > /dev/null
    if [ $? -eq 0 ]
    then
        wifiStatus="on"
    fi
    myprint "[toggle_wifi] Requested: $opt Status: $wifiStatus"
    if [ $opt == "on" ]
    then
        if [ $wifiStatus == "off" ]
        then
            myprint "[toggle_wifi] swipe down"
            sudo input swipe 370 0 370 500
            sleep 5
            myprint "[toggle_wifi] press"
            tap_screen 300 100 2
            myprint "[toggle_wifi] swipe up"
            sudo input swipe 370 500 370 0
        else
            myprint "Requested wifi ON and it is already ON"
        fi
    elif [ $opt == "off" ]
    then
        if [ $wifiStatus == "on" ]
        then
            myprint "[toggle_wifi] swipe down"
            sudo input swipe 370 0 370 500
            sleep 5
            myprint "[toggle_wifi] press"
            tap_screen 300 100 2
            myprint "[toggle_wifi] swipe up"
            sudo input swipe 370 500 370 0
        else
            myprint "Requested wifi OFF and it is already OFF"
        fi
    else
        myprint "Option $opt not supported (on/off)"
    fi
}


echo "toggle_wifi off"
toggle_wifi "off"
timeout 5 /usr/bin/ifconfig wlan0 > wlan-info 2>&1
echo $?
sleep 5 
echo "toggle_wifi on"
toggle_wifi "on"
