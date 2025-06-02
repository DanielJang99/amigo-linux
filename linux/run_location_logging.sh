#!/bin/bash

DEBUG=1
util_file=`pwd`"/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

mkdir -p "locationlogs"
today=`date +\%d-\%m-\%y`
res_file="locationlogs/$today.txt"

# Fetch the public IP address
PUBLIC_IP=$(curl -s https://api64.ipify.org)

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    myprint "Failed to retrieve public IP address."
    exit 0
fi

ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)
if [[ "$ASN_INFO" != *"AS14593"* ]]; then
	myprint "Not a Starlink IP"
	exit 0
fi

ps aux | grep "dish_grpc_text.py location" | grep "python" > ".dish_location_ps"
dish_location_p=`cat ".dish_location_ps" | wc -l`
if [ $dish_location_p -gt 0 ]
then 
    # TODO: check if the last location log is older than 5 minutes
	myprint "Dish location job is running"
	exit 0
fi

myprint "Detected dish_location job not running"
num_attempts=0
flag="false"
while [ $num_attempts -lt 5 ]
do
	python3 test_scripts/starlink_grpc_tools/dish_grpc_text.py location
    if [ $? -eq 0 ]
    then
        nohup python3 test_scripts/starlink_grpc_tools/dish_grpc_text.py location -t 1 -O "$res_file" > .dish_location_log 2>&1 &
        flag="true"
        break
    fi
	num_attempts=$((num_attempts + 1))
    myprint "Attempt $num_attempts failed"
	sleep 1
done

if [ $flag == "false" ]
then
	myprint "Failed to get dish location"
	exit 0
else
	myprint "Dish location job started"
fi

