#!/bin/bash
## Notes:  PLT testing script
## /usr/local/bin/bash <--MAC
## Author: Matteo Varvello (Brave Software)
## Date:   10/28/2019

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    myprint "Trapped CTRL-C"
    killall lighthouse 
    myprint "EXIT!"
    exit -1
}


#helper to  load utilities files
load_file(){
    if [ -f $1 ]
    then
        source $1
    else
        echo "Utility file $1 is missing"
        exit -1
    fi
}

# import utilities files needed
curr_dir=`pwd`
adb_file=$curr_dir"/adb-utils.sh"
load_file $adb_file
curr_dir=`pwd`

# check input 
if [ $# -ne 4 ] 
then 
	echo "================================================================="
	echo "USAGE: $0 device-name browser workload test-id" 
	echo "================================================================="
	exit -1 
fi 

# parameters 
device_name=$1
app=$2
workload=$3
test_id=$4
app_option="None"
intent="android.intent.action.VIEW"
PORT=9222
screen_brightness=70
clean_cache="true"
declare -gA dict_packages                                 # dict of browser packages 
declare -gA dict_activities                               # dict of browser activities

# set timeout based on LTE or not 
use_lte="true"
MAX_DUR=120000
if [ $use_lte == "true" ] 
then
	MAX_DUR=200000
	myprint "LTE emulation was requested. Increase timeout to $MAX_DUR" 
fi 
let "MAX_DURATION = MAX_DUR/1000 + 10"

# turn off previous VPN 
#vpn_off
#my_ip=`curl -s https://ipinfo.io/ip`
#echo "Current IP: $my_ip" 

# populate useful info about device under test
device=$device_name
get_device_info "phones-info.json" $device
if [ -z $adb_identifier ]
then
    myprint "Device $device not supported yet"
    exit -1
fi
usb_device_id=$adb_identifier
device_ip=$ip
device_mac=$mac_address

# find device id to be used and verify all is good
identify_device_id

# VPN setup 
if [ $use_vpn == "true" ] 
then 
	cd /home/pi/openvpn
	(sudo openvpn --config us-ca-102.protonvpn.com.udp.ovpn --auth-user-pass pass.txt > $log_vpn 2>&1 &)
	wait_for_vpn
	cd - > /dev/null 
fi 

# load browser package and activity needed (seems to have issues on mac)
load_browser
app_info

# prep the device 
phone_setup_simple

# load URLs to be tested 
c=0
while read url
do 
	W2[$c]="$url"
	let "c++"
done < "$workload"

# prep the browser 
browser_setup "noclean"
#browser_setup "clean"

# prepping for  lighthouse
#adb kill-server
#sleep 5 
#adb devices 
adb -s $device_id forward --remove-all
echo "Activating port forwarding for devtools (9222) -- Give 15 sec..."
adb -s $device_id forward tcp:$PORT localabstract:chrome_devtools_remote
sleep 15

# iterate on URLs
res_folder="PLT-results/"$test_id"/"$app
mkdir -p $res_folder 

######################TEMP 
#adb -s $device_id shell settings put system screen_brightness 250 
adb -s $device_id shell settings put system screen_brightness $screen_brightness
#############################
redo="false"
for((i=0; i<c; i++))
do
	url=${W2[$i]}
	id=`echo $url | md5sum | cut -f1 -d " "`
	output_path=$res_folder"/"$id".json" 
	log_run=$res_folder"/"$id".log"
	myprint "$url $output_path"
	if [ $use_lte == "false" ] 
	then 
	    timeout $MAX_DURATION lighthouse $url --max-wait-for-load $MAX_DUR --port=9222 --save-assets --throttling-method=provided --output-path=$output_path --output=json --only-categories performance > $log_run 2>&1 
	else 
    	timeout $MAX_DURATION lighthouse $url --max-wait-for-load $MAX_DUR --port=9222 --save-assets --throttling-method=devtools --throttling.requestLatencyMs=70 --throttling.downloadThroughputKbps=12000 --throttling.uploadThroughputKbps=12000 --output-path=$output_path --output=json --only-categories performance > $log_run 2>&1 
	fi 
    #args=(
    #    $url
    #    --config-path config-brave.js
    #    --preset perf
    #    --output json
    #    --output-path $output_path
    #    --save-assets
    #    #--emulated-form-factor none
    #    --throttling-method provided
    #    --max-wait-for-load $MAX_DUR
    #    #--chrome-flags="$chrome_flags"
    #    --port $PORT
    #)
    #timeout $MAX_DURATION lighthouse "${args[@]}" > $log_run 2>&1 

	# clean trace file, huge and not needed
	if [ -f $res_folder"/"$id"-0.trace.json" ] 
	then 
		rm $res_folder"/"$id"-0.trace.json"
	fi 

	# check if a reattempt is needed 
	outfile=$res_folder"/"$id".json"
	if [ -f $outfile ] 
	then 
		cat $outfile | grep -w "speedIndex"
		if [ $? -ne 0 ] 
		then 
			if [ $redo == "false" ] 
			then 
				myprint "Missing observedSpeedIndex. Redo requested" 
				redo="true"
			else
				redo="false"
				myprint "Missing observedSpeedIndex. Redo needed, but only one is allowed. Ignoring"
			fi 
		else 
			redo="false"
		fi 
	else 
		if [ $redo == "false" ] 
		then 
			myprint "Perf. json is missing. Redo requested." 
			redo="true"
		else
			redo="false"
			myprint "Perf. json is missing. Redo needed, but only one is allowed. Ignoring"
		fi 
	fi 

	# each N close all tabs
	let "x = i % 5"
	if [ $x == 4 ]
	then 
		myprint "It is time to close tabs"
		if [ $app == "chrome" ] 
		then
			tap_screen 580 100 3
			tap_screen 660 100 3
			tap_screen 390 300 1 
		elif [ $app == "brave" ] 
		then 
			tap_screen 510 1230 3
			tap_screen 640 1230 3
			tap_screen 310 1045 1 
		fi 
	fi 

	# adjust for a redo 
	if [ $redo == "true" ]
	then 
		myprint "Redo requested (lowering i)"
		let "i--"
	fi 
done 

# turn off VPN if it was used
if [ $use_vpn == "true" ] 
then
	vpn_off
fi 
