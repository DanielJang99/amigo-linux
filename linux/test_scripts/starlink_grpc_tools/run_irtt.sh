#!/data/data/com.termux/files/usr/bin/env bash


# Get current public IP
current_ip=$(curl -s https://api.ipify.org)

if [ -z "$current_ip" ]; then
    echo "Failed to get public IP address"
    exit 1
fi

# Run the Python script with the IP and save output to file
python3 check_starlink_location.py "$current_ip" > closest_server_address.txt

# Check if Python script was successful
if [ $? -ne 0 ]; then
    echo "Failed to determine closest server"
    exit 1
fi

# Read the server IP from file
server_ip=$(cat closest_server_address.txt)

if [ -z "$server_ip" ]; then
    echo "No server IP address found in file"
    exit 1
fi

# Run irtt client
mkdir -p irtt_logs
echo "/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 300s "$server_ip:2112" -o irtt_logs/`date +%s.json`"
/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 300s "$server_ip:2112" -o irtt_logs/`date +%s.json`
