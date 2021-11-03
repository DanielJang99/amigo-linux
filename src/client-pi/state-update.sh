#!/bin/bash
## NOTE: report updates to the central server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
    {
    "timestamp":"${timestamp}",
    "uid":"${uid}",
    "wifi_connection": "${wifi}", 
    "usb_tethering":"${usbTethering}",
    "free_space_GB":"${free_space}",
    "cpu_util_perc":"${cpu_util}",
    "mem_info":"${mem_info}", 
    "phone_foreground":"${foreground}"
    }
EOF
}

# params
timestamp=`date +%s`
MIN_INTERVAL=30

# check if another script is already running 
N_running=`ps aux | grep "state-update"  | grep -v "grep" | wc -l`
ps aux | grep "state-update"  | grep -v "grep"
echo "===> N_running: $N_running"

# get id of phone connected
uid=`adb devices | grep -v "List"  | cut -f 1`

# NOTE: this needs to be called by Kenzo based on user input 
curl -H "Content-Type: application/json" --data '{"uid":"c95ad2777d56", "timestamp":"1635975692", "command_id":"12354", "command":"recharge"}' https://mobile.batterylab.dev:8082/appstatus

# check if kenzo is in the foreground - if yes act accordingly 
foreground=`adb shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
foreground="kenzo" # FIXME: just testing
start_time=`date +%s`
time_passed=0
while [ $foreground == "kenzo" -a $time_passed -lt 60 ] 
do 
	current_time=`date +%s`
	ans=`curl -s https://mobile.batterylab.dev:8082/myaction?id=$uid` 
	command=`echo $ans  | cut -f 1 -d ";"`
	timestamp=`echo $ans  | cut -f 2 -d ";"`
	# verify is allowed command
	if [ $command == "recharge" -o $command == "tether" ] 
	then 
		# verify command is recent 
		delta=`echo "$current_time $timestamp" | awk 'function abs(x){return ((x < 0.0) ? -x : x)} {print(abs($1 - $2))}'`
		if [ $delta -lt 60 ]  #FIXME 
		then 
			echo "Command is allowed" 
			#FIXME: do what needed 
			#FIXME: inform the user 
			break 
		else 
			echo "Command is too old ($delta sec => $ans)"
		fi 
	fi 

	# keep checking status
	foreground=`adb shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g'`
	foreground="kenzo" # FIXME: just testing
	let "time_passed = current_time - start_time"
	sleep 1 
done
if [ $time_passed -ge 60 ] 
then 
	echo "Something wrong. Is user stuck in Kenzo app? Maybe forgot? Go HOME!"
	adb shell "input keyevent KEYCODE_HOME"
fi 
exit -1 

# if not time to report, just exit 
last_report_time="1635969639" #just an old time...
if [ -f ".last_report" ] 
then 
	last_report_time=`cat ".last_report"`
fi 
current_time=`date +%s`
let "time_from_last_report = current_time - last_report_time"
if [ $time_from_last_report -lt $MIN_INTERVAL ] 
then 
	exit 0
fi 
	
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
sleep 2
result=`cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`

# check memory usage
mem_info=`free -m | grep Mem | awk '{print "Total:"$2";Used:"$3";Free:"$4";Available:"$NF}'`

# report data back to control server (when needed)
#echo "$(generate_post_data)" 
curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
echo $current_time > ".last_report"
