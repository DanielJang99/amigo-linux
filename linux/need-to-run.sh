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

# check if we need to install muzeel certificate 
if [ ! -f "/system/etc/security/cacerts/c8750f0d.0" ]
then 
	echo "Installed muzeel certificate"
	sudo mount -o remount,rw /system
	sudo cp c8750f0d.0 /system/etc/security/cacerts/
	sudo chmod 644 /system/etc/security/cacerts/c8750f0d.0
	msg="installed-certificate-"
fi 


# check if debugging or production
debug="true"       # by default we are debugging
if [ -f ".isDebug" ] 
then 
	debug=`cat .isDebug`
else 
	echo "false" > ".isDebug"
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

# inform server of reboot detected 
curr_time=`date +%s`
uptime_sec=`sudo cat /proc/uptime | awk '{print $1}' | cut -f 1 -d "."`
echo "CurrentTime: $curr_time Uptime-sec:$uptime_sec"

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
	git pull
	if [ $? -ne 0 ]
	then
		git stash 
		git pull
	fi
	su -c chmod +rx -R v2/
	
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
	n_sleep=`shuf -i 0-30 -n 1`
	echo "Time to run! Sleep $n_sleep to avoid concurrent restarts"	
	sleep $n_sleep
	today=`date +\%d-\%m-\%y`
	res_dir="logs/$today"	
	mkdir -p $res_dir
	./state-update.sh > "$res_dir/log-state-update-"`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1 &
else 
	echo "No need to run"
fi

# logging
echo `date +\%m-\%d-\%y_\%H:\%M` > ".last"
