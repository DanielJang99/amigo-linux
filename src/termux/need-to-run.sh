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
    "msg":"reboot"
    }
EOF
}

# check if user asked us to pause or not
user_file="/storage/emulated/0/Android/data/com.example.sensorexample/files/running.txt"
user_status="false"
if [ -f $user_file ]
then
	user_status=`sudo cat $user_file`
	if [ $user_status == "true" ]
	then
		echo "false" > ".isDebug"
	else 
		echo "true" > ".isDebug"
	fi
fi 

# don't run if already running
if [ -f ".isDebug" ] 
then 
	debug=`cat .isDebug`
fi 
ps aux | grep "state-update.sh" | grep "bash" > ".ps"
ps aux | grep "state-update.sh" | grep "bash" > ".ps"
N=`cat ".ps" | wc -l`
if [ $N -eq 0 -a $debug == "false" ] 
then 
	echo "need to run"
	./state-update.sh > "logs/log-state-update-"`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1 &
fi

# logging
echo `date +\%m-\%d-\%y_\%H:\%M` > ".last"
