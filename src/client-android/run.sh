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

# log instructions 
myprint "=================================================================================================="
myprint "\tIf asked for password use: $password"
myprint "\tWould you like to enter a view-only password (y/n)? y"
myprint "\t\tEnter same or random password. Not used, but tigervnc 1.9.0 has a bug"
myprint "=================================================================================================="

# switch device if requested
if [ $# -eq 1 ] 
then 
	device_id=$1
	echo "Switching to device $device_id"
fi 

# restart VNC
let "vnc_port = 5900 + screen_id"
myprint "Restarting VNC. Screen: $screen_id Size: $vnc_res Port:$vnc_port"
vncserver -kill :$screen_id > /dev/null 2>&1 
tigervncserver :$screen_id -geometry $vnc_res
if [ $? -ne 0 ]
then 
	vncserver :$screen_id
fi 

# start real device 
for pid in `ps aux | grep 'scrcp\|scrcpy-server.jar' | grep -v "grep" | awk '{print $2}'`
do 
	kill -9 $pid 
done

# export display 
export DISPLAY=:$screen_id

#no-VNC restart 
for pid in `ps aux | grep "websockify" | grep -v "grep" | grep $vnc_port | awk '{print $2}'`
do 
	kill -9 $pid 
done 
for pid in `ps aux | grep "launch.sh" | grep -v "grep" | awk '{print $2}'`
do 
	kill -9 $pid 
done 

# start screen mirroring in virtual screen 
opt="-s $device_id -m 640 -t"
(scrcpy $opt > log_scrcpy 2>&1 &)

# start noVNC
cd $no_vnc_path
myprint "Starting no-vnc (port: $no_vnc_PORT) pointing to VNC on port: $vnc_port"
(./utils/launch.sh --vnc localhost:$vnc_port --listen $no_vnc_PORT > "noVNC-log.txt" 2>&1 &)
cd - > /dev/null 2>&1
