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
ts=`date +%s`
out_file="irtt_logs/"$server_name"_"$ts".json"
echo "/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 180s "$server_ip:2112" -o $out_file"
/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d 180s "$server_ip:2112" -o $out_file
