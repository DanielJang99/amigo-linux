#!/bin/bash
log=$1
receiver_IP=$2
out_log=$3
cat ${log} | awk -v IP=${receiver_IP} '{if($1=="TIME:"){curr_time=$2} if(shouldLog==1){print curr_time" "$0; shouldLog=0;}if(index($0, IP) != 0){shouldLog=1}}' >  ${out_log}
rm ${log} 