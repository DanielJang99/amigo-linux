#!/data/data/com.termux/files/usr/bin/env bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <server_name>"
    exit 1
fi

server_name=$1
server_ip=$(grep "^$server_name," aws_servers.txt | cut -d',' -f3)

if [ -z "$server_ip" ]; then
    echo "No server IP address found for server name: $server_name"
    exit 1
fi
echo $server_ip

# # Run irtt client
mkdir -p irtt_logs
echo "/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 180s "$server_ip:2112" -o irtt_logs/`date +%s.json`"
/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 180s "$server_ip:2112" -o irtt_logs/`date +%s.json`
