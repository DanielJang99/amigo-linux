#!/bin/bash
adb -s e1afce790502 shell am start -n com.android.settings/.TetherSettings
sleep 2 
adb -s e1afce790502 shell input tap 925 1700
sleep 2
adb -s e1afce790502 shell "input keyevent KEYCODE_HOME"

#make sure USB tethering is active
#echo  "Testing USB tethering"
#timeout 10 curl --interface usb0 ifconfig.me
