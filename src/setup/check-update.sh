#!/bin/bash
# NOTE: script to make sure all is ready
# Author: Matteo Varvello (varvello@gmail.com)
# Date: 11/26/2021

# check input 
if [ $# -ne 1 -a $# -ne 2 ] 
then
    echo "================================================================"
    echo "USAGE: $0 wifi-ip [production]"
    echo "================================================================"
    exit -1 
fi 

# close all pending applications
close_all(){
    # go HOME
    sudo input keyevent KEYCODE_HOME

    # enter switch application tab
    sudo input keyevent KEYCODE_APP_SWITCH
    sleep 2

    # press close all
    tap_screen 370 1210
}


# helper to insall apk via wifi/ssh
install_simple(){
	# read input 
	if [ $# -ne 2 ] 
	then 
		echo "ERROR. Missing params to install_simple"
		exit -1 
	fi
	pkg=$1
	apk=$2
	echo "[install_simple] $pkg"
	cat  "../installed-pkg/$wifi_ip" | grep $pkg 
	to_install=$?
	if [ $to_install -eq 1 ]
	then 
		./install-app-wifi.sh $wifi_ip $apk
	else
		echo "$pkg is already installed"
	fi 
}

# parameters 
wifi_ip=$1                      # device to be prepped 
ssh_key="id_rsa_mobile"           # unique key used for both SSH and GITHUB 
password="termux"                 # default password
termux_pack="com.termux"          # termux package 
termux_boot="com.termux.boot"     # termux boot package 
termux_api="com.termux.api"       # termux API package 
production="false"                # default we are debugging 

# check if we want to switch to production
if [ $# -eq 2 ] 
then 
	echo "WARNING. Requested switching to production!"
	production="true"
fi 

# make sure nmap is installed 
hash nmap
if [ $? -ne 0 ] 
then 
	echo "Installing nmap since missing" 
	sudo apt install -y nmap
fi 

# verify phone is on wifi
sudo nmap -p 8022 $wifi_ip | grep closed
if [ $? -eq 0 ] 
then 
	echo "ERROR. Phone is not reachable via $wifi_ip"
	exit -1 
fi 
echo "OK. Phone is reachable via $wifi_ip"

# list installed packages 
mkdir -p "installed-pkg"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "pm list packages -f" > "installed-pkg/$wifi_ip"

# make sure phone is reachable via adb 
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo input keyevent KEYCODE_HOME && sudo input keyevent 111"	

# verify termux related stuff is installed (should be) 
cd APKs
install_simple $termux_pack "com.termux_117.apk"     #https://f-droid.org/repo/com.termux_117.apk
install_simple $termux_api "com.termux.api_49.apk"	 #https://f-droid.org/repo/com.termux.api_49.apk
install_simple $termux_boot "com.termux.boot_7.apk"  #https://f-droid.org/repo/com.termux.boot_7.apk
cd - > /dev/null 2>&1

# make sure crontab is enabled (FIXME)
#ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sv-enable crond"
#fail: crond: unable to change to service directory: file does not exist

# install apps needed
package_list[0]="com.google.android.apps.maps"
package_list[1]="us.zoom.videomeetings"
package_list[2]="com.cisco.webex.meetings"
package_list[3]="com.google.android.apps.meetings"
package_list[4]="com.google.android.youtube"
package_list[5]="com.example.sensorexample"
name_list[0]="google\ maps"
name_list[1]="zoom"
name_list[2]="webex"
name_list[3]="google\ meet"
name_list[4]="youtube"
name_list[5]="kenzo"
apk_list[0]="com.google.android.apps.maps_11.7.5.apk"
apk_list[1]="us.zoom.videomeetings_5.8.4.2783.apk"
apk_list[2]="com.cisco.webex.meetings_41.11.0.apk"
apk_list[3]="com.google.android.apps.meetings_2021.10.31.apk"
apk_list[4]="com.google.android.youtube_16.46.35.apk"
apk_list[5]="app-debug.apk"
num_apps="${#package_list[@]}"
first="true"
cd APKs
for((i=0; i<num_apps; i++))
do
    package=${package_list[$i]}
    name=${name_list[$i]}
	apk=${apk_list[$i]}
	echo "install_simple $package $apk"
	install_simple $package $apk
done
cd - > /dev/null 2>&1
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo input keyevent KEYCODE_HOME"	

# launch termux-boot to make sure it is ready 
echo "launching termux-boot to make sure it is ready"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo monkey -p $termux_boot 1 > /dev/null 2>&1"
sleep 5 
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "sudo input keyevent KEYCODE_HOME"	

# update code 
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "cd mobile-testbed/src/setup && git pull"
if [ $production == "true" ] 
then 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"false\" > \"mobile-testbed/src/termux/.isDebug\"" 
else 
	ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "echo \"true\" > \"mobile-testbed/src/termux/.isDebug\"" 
fi 

# make sure all permissions are granted 
todo="sudo pm grant com.termux.api android.permission.READ_PHONE_STATE"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "$todo"
todo="sudo pm grant com.google.android.apps.maps android.permission.ACCESS_FINE_LOCATION"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "$todo"
todo="sudo pm grant com.example.sensorexample android.permission.ACCESS_FINE_LOCATION"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "$todo"
todo="sudo pm grant com.example.sensorexample android.permission.READ_PHONE_STATE"
ssh -oStrictHostKeyChecking=no -i $ssh_key -p 8022 $wifi_ip "$todo"

# logging 
echo "All good"
