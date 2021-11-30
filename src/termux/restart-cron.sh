#!/data/data/com.termux/files/usr/bin/env bash

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

# restart crond and inform server of reboot
up_min=`uptime | awk '{print $3}'`
echo "Uptime: $up_min mins"
if [ $up_min -le 3 ] 
then
	suffix=`date +%d-%m-%Y`
	current_time=`date +%s`
	uid=`termux-telephony-deviceinfo | grep "device_id" | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
	uptime_info=`uptime`
	echo "$(generate_post_data)"
	timeout 10 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/status
	for pid in `ps aux | grep "crond -n -s" | grep -v "grep" | awk '{print $2}'`
	do 
		echo "Restarting CROND by killing PID: $pid"
		kill -9 $pid
	done
fi 
