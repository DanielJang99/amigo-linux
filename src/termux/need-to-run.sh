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

# check if we need to install muzeel certificate 
if [ ! -f "/system/etc/security/cacerts/c8750f0d.0" ]
then 
	echo "Installed muzeel certificate"
	sudo mount -o remount,rw /system
	sudo cp c8750f0d.0 /system/etc/security/cacerts/
	sudo chmod 644 /system/etc/security/cacerts/c8750f0d.0
	msg="installed-certificate-"
fi 

dev_model=`getprop ro.product.model | sed s/" "//g`
if [[ "$dev_model" == "SM-A346E" || "$dev_model" == "SM-G996B"* ]] 
then 
	uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
	# handle edge case when imei for sim2 is reported instead 
	# if [ -z $physical_id ]
	# then 
	# 	turn_device_on
	# 	su -c cmd statusbar expand-settings
	# 	sleep 1 
	# 	sudo input tap 250 1350 
	# 	sleep 1
	# 	sudo input tap 250 1350 
	# 	sleep 1 
	# 	turn_device_off
	# 	sleep 10 
	# 	uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
	# 	physical_id=`cat "uid-list.txt" | grep $uid | head -n 1 | awk '{print $1}'`
	# fi
else
	uid=`termux-telephony-deviceinfo | grep "device_id" | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
fi

# check if debugging or production
debug="true"       # by default we are debugging
if [ -f ".isDebug" ] 
then 
	debug=`cat .isDebug`
fi 

# retrieve last used server port 
if [ -f ".server_port" ] 
then 
	SERVER_PORT=`cat ".server_port"`
else 
	SERVER_PORT="8082"
fi 

# add reboot jobs if missing  (unless we are in debug mode)
msg=""
crontab -l | grep reboot
if [ $? -eq 1 ]
then 
	echo "Detected need to add reboot job"
	if [ $debug == "false" ]
	then
		(crontab -l 2>/dev/null; echo "0 2 * * * sudo reboot") | crontab -
		msg="added-reboot-"
	else 
		echo "Skipping adding reboot job since debug=$debug"
	fi 
fi 

# inform server of reboot detected 
curr_time=`date +%s`
uptime_sec=`sudo cat /proc/uptime | awk '{print $1}' | cut -f 1 -d "."`
echo "CurrentTime: $curr_time Uptime-sec:$uptime_sec"
if [ $uptime_sec -le 180 ] 
then
	suffix=`date +%d-%m-%Y`
	current_time=`date +%s`
	uptime_info=`uptime`
	msg=$msg"reboot"
	echo "$(generate_post_data)"
	echo "false" > .isDebug
	timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/status
fi 

# don't run if already running
ps aux | grep "state-update.sh" | grep "bash" > ".ps"
N=`cat ".ps" | wc -l`
if [ $N -eq 0 -a $debug == "false" ] 
then 
	# inform server of restart needed
	suffix=`date +%d-%m-%Y`
	current_time=`date +%s`
	uptime_info=`uptime`
	msg="script-restart"
	echo "$(generate_post_data)"
	timeout 10 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/status

	node --version 
	if [ $? -ne 0 ]
	then
		yes | pkg install -y nodejs
	fi

	traceroute --version 
	if [ $? -ne 0 ]
	then 
		yes | pkg install -y traceroute
	fi

	# update code 
	myprint "Updating our code..."
	git stash
	git pull
	su -c chmod 755 -R v2/
	
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

	# check if Kenzo needs to be updated 
	./update_kenzo.sh 

	# check if visual_metrics is installed in this directory 
	./check-visual.sh
		
	# restart script 
	n_sleep=`shuf -i 0-30 -n 1`
	echo "Time to run! Sleep $n_sleep to avoid concurrent restarts"	
	sleep $n_sleep
	today=`date +\%m-\%d-\%y`
	res_dir="logs/$today"	
	mkdir -p $res_dir
	if [[ "$dev_model" == "SM-A346E" || "$dev_model" == "SM-G996B" ]] 
	then 
		./v2/state-update.sh > "$res_dir/log-state-update-"`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1 &
	else 
		./state-update.sh > "logs/log-state-update-"`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1 &
	fi
else 
	echo "No need to run"
fi

# logging
echo `date +\%m-\%d-\%y_\%H:\%M` > ".last"
