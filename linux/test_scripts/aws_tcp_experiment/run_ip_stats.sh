#!/data/data/com.termux/files/usr/bin/env bash

function myprint(){
    timestamp=`date +%s`
    val=$1
    if [ $# -eq  0 ]
    then
        return 
    fi
    echo -e "\033[32m[$0][$timestamp]\t${val}\033[0m"      
}

myprint "Timestamp: `date +%s`"

# Create network_stats directory if it doesn't exist
mkdir -p network_stats

# Get current date in YYYY-MM-DD format
TODAY=$(date +"%Y-%m-%d")
FILENAME="network_stats/${TODAY}_stats_min.csv"

# Get public IP address (using ipify API)
PUBLIC_IP=$(curl -s 'https://api.ipify.org')

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    myprint "Failed to retrieve public IP address."
    exit 0
fi

ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)

if [[ "$ASN_INFO" == *"AS14593"* ]]; then
    myprint "Public IP is in the Starlink network."
    
    # Update epoch timestamp for each iteration
    EPOCH=$(date +%s)
    
    if [ ! -f "$FILENAME" ]; then
        # Create header if file doesn't exist
        echo "timestamp,public_ip" > "$FILENAME"
    fi

    # Append data to CSV file
    echo "${EPOCH},${PUBLIC_IP}" >> "$FILENAME"
fi