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
    # exit 0     
fi


# Create network_stats directory if it doesn't exist
mkdir -p network_stats

# Get current date in YYYY-MM-DD format
TODAY=$(date +"%Y-%m-%d")
FILENAME="network_stats/${TODAY}_stats_min.csv"

# Get current epoch timestamp
EPOCH=$(date +%s)

# Define ping destination
PING_DEST="100.64.0.1"

# Get public IP address (using ipify API)
PUBLIC_IP=$(curl -s 'https://api.ipify.org')

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    echo "Failed to retrieve public IP address."
    exit 0
fi

ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)

if [[ "$ASN_INFO" == *"AS14593"* ]]; then
    echo "Public IP is in the Starlink network."
    
    # Calculate end time (current time + 59 seconds)
    END_TIME=$(($(date +%s) + 59))
    
    # Run until we reach END_TIME
    while [ $(date +%s) -lt $END_TIME ]; do
        # Update epoch timestamp for each iteration
        EPOCH=$(date +%s)
        
        # Get ping statistics with a single command
        PING_OUTPUT=$(ping -c 1 -W 1 $PING_DEST 2>/dev/null)
        
        if [ ! -f "$FILENAME" ]; then
            # Create header if file doesn't exist
            echo "timestamp,public_ip,packets_transmitted,packets_received,min_ping,avg_ping,max_ping,mdev" > "$FILENAME"
        fi

        # Extract ping statistics
        if [ -z "$PING_OUTPUT" ]; then
            # If ping failed, use empty values
            PING_RESULT="0,0,0,0,0,0"
        else
            PACKETS=$(echo "$PING_OUTPUT" | grep "packets transmitted" | awk -F'[ ,]' '{print $1 "," $4}')
            PING_TIMES=$(echo "$PING_OUTPUT" | tail -1 | awk -F'[/ ]' '{print $7 "," $8 "," $9 "," $10}')
            PING_RESULT="${PACKETS},${PING_TIMES}"
        fi

        # Append data to CSV file
        echo "${EPOCH},${PUBLIC_IP},${PING_RESULT}" >> "$FILENAME"
        
        # Wait for 1 second before next iteration
        sleep 1
    done
fi