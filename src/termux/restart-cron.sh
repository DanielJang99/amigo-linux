#!/data/data/com.termux/files/usr/bin/env bash
date
uptime | awk '{print $3}'
up_sec=`uptime | awk '{print $3}'`
if [ $up_sec -le 10 ] 
then
	echo "here"
	for pid in `ps aux | grep "crond -n -s" | grep -v "grep" | awk '{print $2}'`
	do 
		echo "Restarting CROND by killing PID: $pid"
		kill -9 $pid
	done
fi 
