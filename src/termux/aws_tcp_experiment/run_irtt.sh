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

if [ $# -lt 1 ]; then
    myprint "Usage: $0 <server_name> [duration_seconds]"
    exit 1
fi

server_name=$1
duration=${2:-180}
server_ip=$(grep "^$server_name," aws_servers.txt | cut -d',' -f3)

if [ -z "$server_ip" ]; then
    myprint "No server IP address found for server name: $server_name"
    exit 1
fi
myprint "Server IP: $server_ip"

# # Run irtt client
mkdir -p irtt_logs
ts=`date +%s`
out_file="irtt_logs/"$server_name"_"$ts".json"
myprint "/data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d ${duration}s "$server_ip:2112" -o $out_file"
# /data/data/com.termux/files/home/go/bin/irtt client -i 10ms -d ${duration}s "$server_ip:2112" -o $out_file
