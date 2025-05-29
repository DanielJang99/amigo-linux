#!/bin/bash

function clean_file(){
        if [ -f $1 ]
        then
                rm -v $1
        fi
}

opt=$1
runMode="simple"
if [ $# -gt 1 ]
then
        runMode=$2
fi 
if [ ${runMode}  == "full" ]
then
        if [ ${opt} == "sender" ]
        then
                clean_file "sender-log"
        fi
        if [ ${opt} == "receiver" ]
        then
                clean_file "receiver-log"
        fi
fi

# make sure tcpdump is not running anymore
for pid in `ps aux | grep "tcpdump" | grep -v "grep" | awk '{print $2}'`
do
        sudo kill -9 ${pid}
done

# stop python code (client and server)
for pid in `ps aux | grep "python" | grep "${opt}" | grep -v "grep" | awk '{print $2}'`
do
        #sudo kill -9 ${pid}
        sudo kill ${pid}  # Use SIGTERM instead of SIGKILL
done