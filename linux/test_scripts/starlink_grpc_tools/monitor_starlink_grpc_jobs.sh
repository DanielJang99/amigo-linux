#!/bin/bash
## NOTE: monitor starlink grpc jobs 
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 2025-06-02


DEBUG=1
util_file="/amigo-linux/linux/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

today=`date +\%d-\%m-\%y`
# Fetch the public IP address
PUBLIC_IP=$(curl -s https://api64.ipify.org)

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    myprint "Failed to retrieve public IP address."
    exit 0
fi
myprint "Public IP: $PUBLIC_IP"
script_path="/amigo-linux/linux/test_scripts/starlink_grpc_tools"
status_results_path="/amigo-linux/linux/results/dish_status"
mkdir -p $status_results_path
obs_results_path="/amigo-linux/linux/results/obstruction_maps"
mkdir -p $obs_results_path

# Fetch ASN details using ipinfo.io (alternative: whois command)
ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)
if [[ "$ASN_INFO" == *"AS14593"* ]]; then
    ps aux | grep "dish_grpc_text.py status" | grep "python" > ".dish_status_ps"
    dish_status_p=`cat ".dish_status_ps" | wc -l`
    if [ $dish_status_p -eq 0 ]
    then 
        myprint "Detected dish_status job not running"
        (nohup python3 $script_path/dish_grpc_text.py status -t 1 -O $status_results_path/$today.csv > grpc_text.log 2>&1 &)
    fi 

    ps aux | grep "get_obstruction_raw" | grep "python" > ".dish_obs_ps"
    dish_obs_p=`cat ".dish_obs_ps" | wc -l`
    if [ $dish_obs_p -eq 0 ]
    then 
        myprint "Detected obstruction_map job not running"
        (nohup python3 get_obstruction_raw.py $obs_results_path -t 1 > obs_map.log 2>&1 &)
    fi 
    exit 0
else
	myprint "not starlink asn"
    exit 0
fi
