#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: check if there is something to run 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "uptime":"${uptime_info}",
    "debug":"${debug}",
    "msg":"${msg}"
    }
EOF
}

# check if user asked us to pause or not # not needed anymore
# user_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/running.txt"
# user_status="false"
# if [ -f $user_file ]
# then
# 	user_status=`sudo cat $user_file`
# 	if [ $user_status == "true" ]
# 	then
# 		echo "User pressed \"resume\""
# 		echo "false" > ".isDebug"
# 	else 
# 		echo "User pressed \"pause\""
# 		echo "true" > ".isDebug"
# 	fi
# fi 

# check if debugging or production
if [ -f ".isDebug" ] 
then 
	debug=`cat .isDebug`
fi 

# add reboot jobs if missing
msg=""
crontab -l | grep reboot
if [ $? -eq 1 ]
then 
	echo "Detected need to add a new job"
	(crontab -l 2>/dev/null; echo "0 2 * * * sudo reboot") | crontab -
	#(crontab -l 2>/dev/null; echo "0 0 * * * sudo reboot") | crontab -
	msg="added-reboot-"
fi 

# inform server of reboot detected 
curr_time=`date +%s`
uptime_sec=`sudo cat /proc/uptime | awk '{print $1}' | cut -f 1 -d "."`
echo "CurrentTime: $curr_time Uptime-sec:$uptime_sec"
if [ $uptime_sec -le 180 ] 
then
	suffix=`date +%d-%m-%Y`
	current_time=`date +%s`
	uid=`termux-telephony-deviceinfo | grep "device_id" | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
	uptime_info=`uptime`
	msg=$msg"reboot"
	echo "$(generate_post_data)"
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
fi 

# don't run if already running
ps aux | grep "state-update.sh" | grep "bash" > ".ps"
N=`cat ".ps" | wc -l`
if [ $N -eq 0 -a $debug == "false" ] 
then 
	# inform server of restart needed
	suffix=`date +%d-%m-%Y`
	current_time=`date +%s`
	uid=`termux-telephony-deviceinfo | grep "device_id" | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
	uptime_info=`uptime`
	msg="script-restart"
	echo "$(generate_post_data)"
	timeout 10 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status

	# update code 
	myprint "Updating our code..."
	git pull
	
	# make sure net-testing is stopped
	./stop-net-testing.sh  	

	# check if there is something to compress 	
	for f in `ls logs | grep 'state\|net'`
	do  
		echo $f | grep -E "\.gz" > /dev/null
		if [ $? -eq 1 ] 
		then 
			gzip "logs/${f}"
		fi 
	done
		
	# restart script 
	echo "Time to run!"	
	mkdir -p logs	
	./state-update.sh > "logs/log-state-update-"`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1 &
else 
	echo "No need to run"
fi

# logging
echo `date +\%m-\%d-\%y_\%H:\%M` > ".last"