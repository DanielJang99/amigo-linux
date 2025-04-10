#!/data/data/com.termux/files/usr/bin/env bash

# Helper for better logging
function myprint(){
    timestamp=`date +%s`
    val=$1
    if [ $# -eq  0 ]
    then
        return 
    fi
    echo -e "\033[32m[$0][$timestamp]\t${val}\033[0m"      
}

# Check if dig is installed
if ! command -v dig &> /dev/null; then
    myprint "dig not found, installing dnsutils..."
    pkg install dnsutils -y
    exit 0
fi

# Get current public IP and its hostname
PUBLIC_IP=$(curl -s ifconfig.me)
# PUBLIC_IP="129.222.238.135"
CURRENT_HOSTNAME=$(dig +short -x "$PUBLIC_IP" | sed 's/\.$//')
CURRENT_EPOCH=$(date +%s)

# Only proceed if hostname contains starlinkisp.net
if [[ "$CURRENT_HOSTNAME" != *"starlinkisp.net"* ]]; then
    myprint "Hostname $CURRENT_HOSTNAME does not contain starlinkisp.net - skipping"
    exit 0
fi


# Check if the script is already running
if pgrep -f "$0" > /dev/null; then
    myprint "Script is already running - skipping"
    exit 0
fi

# Check if track_hostname.sh is running
if pgrep -f "track_hostname.sh" > /dev/null; then
    myprint "track_hostname.sh is already running - skipping"
    exit 0
fi


# Check if track_hostname_ldn.sh is running
if pgrep -f "track_hostname_ldn.sh" > /dev/null; then
    myprint "track_hostname_ldn.sh is already running - skipping"
    exit 0
fi

# check if run_irtt_server.sh is running
if pgrep -f "run_irtt.sh" > /dev/null; then
    myprint "run_irtt.sh is already running - skipping"
    exit 0
fi

if [[ "$CURRENT_HOSTNAME" == *"customer.nwyynyx"* ]]; then
    myprint "Running irtt for us-east-1"
    ./run_irtt.sh us-east-1 300
    exit 0 
fi

if [[ "$CURRENT_HOSTNAME" == *"customer.lndngbr"* ]]; then
    myprint "Running irtt for eu-west-2"
    ./run_irtt.sh eu-west-2 300
    exit 0
fi

if [[ "$CURRENT_HOSTNAME" == *"customer.frntdeu"* ]]; then
    myprint "Running irtt for eu-central-1"
    ./run_irtt.sh eu-central-1 300
    exit 0
fi

if [[ "$CURRENT_HOSTNAME" == *"customer.mlnnita1"* ]]; then
    myprint "Running irtt for eu-south-1"
    ./run_irtt.sh eu-south-1 300
    exit 0
fi


if [[ "$CURRENT_HOSTNAME" == *"customer.mdrdesp1"* ]]; then
    myprint "Running irtt for eu-south-2"
    ./run_irtt.sh eu-south-2 300
    exit 0
fi

if [[ "$CURRENT_HOSTNAME" == *"customer.dohaqat"* ]]; then
    myprint "Running irtt for me-central-1"
    ./run_irtt.sh me-central-1 300
    exit 0
fi