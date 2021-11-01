#!/bin/bash
# NOTE: update tunnel info at Matteo's machine in case of a reboot 

iot_proxy="iot.batterylab.dev"  # address of iot proxy 
ps aux | grep ngrok | grep 22
if [ $? -ne 0 ] 
then 
	cd ..
	(./ngrok tcp 22 --config .ngrok2/ngrok2.yml > log 2>&1 &)
	sleep 3 
fi 
curl http://localhost:4040/api/tunnels > "log-tunnel" 2>/dev/null
timeout 10 scp -o StrictHostKeyChecking=no -P 12345 "log-tunnel" $iot_proxy:
