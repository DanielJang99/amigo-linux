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

isStarlink="false"  
isStarlink_fpath="/data/data/com.termux/files/home/mobile-testbed/src/termux/.isStarlink"
if [ -f $isStarlink_fpath ] 
then
	isStarlink=`cat "$isStarlink_fpath"`
fi

if [ $isStarlink == "false" ]
then
    echo "isStarlink set to false"
    # exit 0     
fi

# Get current public IP and its hostname
PUBLIC_IP=$(curl -s ifconfig.me)
# PUBLIC_IP="129.222.238.135"
CURRENT_HOSTNAME=$(dig +short -x "$PUBLIC_IP" | sed 's/\.$//')
CURRENT_EPOCH=$(date +%s)

# If hostname resolution failed, use the IP as hostname
if [ -z "$CURRENT_HOSTNAME" ]; then
    CURRENT_HOSTNAME=$PUBLIC_IP
fi

# Only proceed if hostname contains starlinkisp.net
if [[ "$CURRENT_HOSTNAME" != *"starlinkisp.net"* ]]; then
    myprint "Hostname $CURRENT_HOSTNAME does not contain starlinkisp.net - skipping"
    exit 0
fi

# Define common parameters
RATE=80
DUR=180

# Create hostnames.txt if it doesn't exist
touch hostnames.txt

grep_val="receiver.py" 
ans=`ps aux | grep "${grep_val}" | grep -v "grep" | wc -l`

# Check if hostname exists in file
if grep -q "^$CURRENT_HOSTNAME," hostnames.txt; then
    # Hostname exists, check timestamp
    LAST_LINE=$(grep "^$CURRENT_HOSTNAME," hostnames.txt)
    LAST_EPOCH=$(echo "$LAST_LINE" | cut -d',' -f2)
    WAS_EXECUTED=$(echo "$LAST_LINE" | cut -d',' -f3)
    TIME_DIFF=$((CURRENT_EPOCH - LAST_EPOCH))
    myprint "TIME_DIFF: $TIME_DIFF"

    # NY PoP: 30 minutes after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.nwyynyx"* && $TIME_DIFF -ge 1800 && $TIME_DIFF -le 3600 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 30 minutes - starting aws experiment to us-east-1"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID us-east-1
        # myprint "Executing: run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID me-central-1"
        # ./run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID me-central-1

        exit 0
    fi

    # London PoP: 60-90 minutes after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.lndngbr"* && $TIME_DIFF -ge 3600 && $TIME_DIFF -le 5400 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 60-90 minutes - starting aws experiment to eu-west-2"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s eu-west-2 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID eu-west-2"
        ./run-aws-client.sh -s eu-west-2 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID eu-west-2
        myprint "Executing: run-aws-client.sh -s eu-west-2 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID eu-west-2"
        ./run-aws-client.sh -s eu-west-2 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID eu-west-2
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1

        exit 0
    fi

    # Frankfurt PoP: 800-1500 seconds after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.frntdeu"* && $TIME_DIFF -ge 800 && $TIME_DIFF -le 1500 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 800-1500 seconds - starting aws experiment to eu-central-1"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID eu-central-1"
        ./run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID eu-central-1     
        myprint "Executing: run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID eu-central-1  "
        ./run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID eu-central-1
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1

        exit 0
    fi

    # milan PoP: right after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.mlnnita1"* && $TIME_DIFF -ge 1 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 10 minutes - starting aws experiment to eu-south-1"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s eu-south-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID eu-south-1"
        ./run-aws-client.sh -s eu-south-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID eu-south-1
        myprint "Executing: run-aws-client.sh -s eu-south-1 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID eu-south-1"
        ./run-aws-client.sh -s eu-south-1 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID eu-south-1
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1

        exit 0  
    fi

    # Madrid PoP: 30 minutes after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.mdrdesp1"* && $TIME_DIFF -ge 1800 && $TIME_DIFF -le 3600 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 30 minutes - starting aws experiment to eu-south-2"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s eu-south-2 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID eu-south-2"
        ./run-aws-client.sh -s eu-south-2 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID eu-south-2
        myprint "Executing: run-aws-client.sh -s eu-south-2 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID eu-south-2"
        ./run-aws-client.sh -s eu-south-2 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID eu-south-2
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1

        exit 0
    fi

    # # Sofia PoP: 60-90 minutes after first encounter 
    # if [[ "$CURRENT_HOSTNAME" == *"customer.sfiabgr"* && $TIME_DIFF -ge 3600 && $TIME_DIFF -le 5400 && "$WAS_EXECUTED" != "1" ]]; then
    #     echo "Detected target hostname after 60-90 minutes - starting aws experiment to eu-central-1"
    #     # Update entry with execution flag
    #     grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
    #     echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
    #     mv hostnames.tmp hostnames.txt

    #     if [ $ans -gt 0 ]
    #     then
    #         myprint "Receiver already running - skipping"
    #         exit 0
    #     fi

    #     myprint "Executing: run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID eu-central-1"
    #     ./run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID eu-central-1
    #     myprint "Executing: run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID eu-central-1"
    #     ./run-aws-client.sh -s eu-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID eu-central-1
    #     myprint "Executing: run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID me-central-1"
    #     ./run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID me-central-1

    #     exit 0
    # fi

    # Doha PoP: 30-60 minutes after first encounter 
    if [[ "$CURRENT_HOSTNAME" == *"customer.dohaqat"* && $TIME_DIFF -ge 1800 && $TIME_DIFF -le 3600 && "$WAS_EXECUTED" != "1" ]]; then
        echo "Detected target hostname after 30-60 minutes - starting aws experiment to me-central-1"
        # Update entry with execution flag
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,1" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt

        if [ $ans -gt 0 ]
        then
            myprint "Receiver already running - skipping"
            exit 0
        fi

        myprint "Executing: run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID me-central-1"
        ./run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID me-central-1
        myprint "Executing: run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e $CURRENT_EPOCH --ID me-central-1"
        ./run-aws-client.sh -s me-central-1 --dur $DUR -r $RATE --tcpdump -c bbr -e "$CURRENT_EPOCH" --ID me-central-1
        myprint "Executing: run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e $CURRENT_EPOCH --ID us-east-1"
        ./run-aws-client.sh -s us-east-1 --dur $DUR -r $RATE --tcpdump -e "$CURRENT_EPOCH" --ID us-east-1
        exit 0
    fi

    
    # If more than 24 hours, update timestamp
    if [ $TIME_DIFF -gt 86400 ]; then
        echo "Updating existing entry for $CURRENT_HOSTNAME (last seen $TIME_DIFF seconds ago)"
        grep -v "^$CURRENT_HOSTNAME," hostnames.txt > hostnames.tmp
        echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,0" >> hostnames.tmp
        mv hostnames.tmp hostnames.txt
    fi
else
    # New PoP, append entry
    myprint "Adding new entry for $CURRENT_HOSTNAME"
    echo "$CURRENT_HOSTNAME,$CURRENT_EPOCH,0" >> hostnames.txt
fi 
