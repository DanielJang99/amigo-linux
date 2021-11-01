#!/bin/bash

# simple function for logging
myprint(){
    timestamp=`date +%s`
    if [ $DEBUG -gt 0 ]
    then
        if [ $# -eq  0 ]
        then
            echo -e "[ERROR][$timestamp]\tMissing string to log!!!"
        else
        	if [ $# -eq  1 ]
			then
	            echo -e "[$0][$timestamp]\t" $1
			else
	            echo -e "[$0][$timestamp][$2]\t" $1
			fi
        fi
    fi
}

# clean a file
clean_file(){
    if [ -f $1 ]
    then
        rm $1
    fi
}

# parameters 
DEBUG=1
password="mazinga" 
x_vnc=500
y_vnc=800
vnc_res=$x_vnc"x"$y_vnc
screen_id=3
device_id="LGH870eb6286bb"
no_vnc_PORT=6081
no_vnc_path="noVNC-1.0.0"

# start real device 
for pid in `ps aux | grep 'scrcp\|scrcpy-server.jar' | grep -v "grep" | awk '{print $2}'`
do 
	kill -9 $pid 
done

# export display 
export DISPLAY=:$screen_id

# start screen mirroring in virtual screen 
opt="-s $device_id -m 640 -t"
(scrcpy $opt > log_scrcpy 2>&1 &)

echo "rstarted" 
