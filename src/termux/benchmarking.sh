#!/bin/bash
## NOTE: benchmarking the server 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 12/10/2021

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    exit -1 
}

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "uptime":"${uptime_info}",
    "debug":"${debug}",
    "msg":"${msg}"
    }
EOF
}

# main code 
uid=$1
port=$2
suffix=`date +%d-%m-%Y`
current_time=`date +%s`
uptime_info=`uptime`
msg="benchmarking"
t_s=`date +%s`
timeout 30 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$port/benchmarking
t_e=`date +%s`
let "t_p = t_e - t_s"
echo "[$uid] Duration: $t_p"
