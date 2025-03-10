#!/data/data/com.termux/files/usr/bin/env bash

echo "Timestamp: `date +%s`"

isStarlink="false"  
isStarlink_fpath="/data/data/com.termux/files/home/mobile-testbed/src/termux/.isStarlink"
if [ -f $isStarlink_fpath ] 
then
	isStarlink=`cat "$isStarlink_fpath"`
fi

if [ $isStarlink == "false" ]
then
    echo "isStarlink set to false"
    exit 0     
fi

./setup_starlink_grpc.sh

# Fetch the public IP address
PUBLIC_IP=$(curl -s https://api64.ipify.org)

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    echo "Failed to retrieve public IP address."
    exit 0
fi

echo "Public IP: $PUBLIC_IP"

# Fetch ASN details using ipinfo.io (alternative: whois command)
ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)

if [[ "$ASN_INFO" == *"AS14593"* ]]; then
    ps aux | grep "dish_grpc_text" | grep "python" > ".dish_status_ps"
    dish_status_p=`cat ".dish_status_ps" | wc -l`
    if [ $dish_status_p -eq 0 ]
    then 
        echo "Detected dish_status job not running"
        (python3 dish_grpc_text.py status -t 1 -O ./dish_status/status_`date +%s`.csv > /dev/null 2>&1 &)
    fi 

    ps aux | grep "dish_obstruction_map" | grep "python" > ".dish_obs_ps"
    dish_obs_p=`cat ".dish_obs_ps" | wc -l`
    if [ $dish_obs_p -eq 0 ]
    then 
        echo "Detected obstruction_map job not running"
        (python3 dish_obstruction_map.py -t 1 ./obstruction_maps/obstructions_`date +%s`.png > /dev/null 2>&1 &)
    fi 
    exit 0
else
	echo "not starlink asn"
    exit 0
fi
