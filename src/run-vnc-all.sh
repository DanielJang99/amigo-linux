#!/bin/bash 
## Set up remote access to all connected Android devices
## Author: Matteo Varvello (varvello@gmail.com)
## Date: 12/03/2021

# print script usage 
usage(){
    echo "===================================================================="
    echo "USAGE: $0 -s,--screen p,--port -h,--help, --id"
    echo "===================================================================="
    echo "-s,--screen     Virtual screen to be used (default :3)"
    echo "-v,--video      Record screen (default: False)" 
    echo "-p,--port       noVNC port (default: 6081)" 
    echo "-h,--help       Shows an helper" 
    echo "--id            Session identifier"
    echo "===================================================================="
    exit -1 
}

# my logging function 
myprint(){
	timestamp=`date +%s`
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
}

# general parameters 
screen_id=3                                  # (virtual) display ID 
curr_dir=`pwd`                               # folder where script is run
log_folder=$curr_dir"/logs"                  # folder where all logs go 
record_screen="False"                        # by default do not record screen
no_vnc_PORT=6083                             # deafult port used by no-VNC
no_vnc_path="./noVNC-1.0.0"                  # path for noVNC tool 
session_id="testing"                         # session identifier for logging
def_port=5555                                # default port used by adb over wifi
                        
# read input parameters
while [ "$#" -gt 0 ]
do
	case "$1" in
	-s | --screen)
		shift;
		screen_id="$1"
		shift
		;;
	-v | --video)
		shift;
		record_screen="True" 
		shift
		;;
	-p | --port)
		shift;
		no_vnc_PORT="$1" 
		shift
		;;
	--id)
		shift;
		session_id="$1" 
		shift
		;;
	-h | --help)
		usage
		;;
	-*)
		myprint "ERROR: Unknown option $1"
		usage
		;;
	esac
done

# folder management 
mkdir -p $log_folder

# restart VNC
x_vnc=1300
y_vnc=1600
vnc_res=$x_vnc"x"$y_vnc
myprint "Restarting VNC. Screen: $screen_id Size: $vnc_res"
sudo vncserver -kill :$screen_id > /dev/null 2>&1 
sudo tigervncserver :$screen_id -geometry $vnc_res
if [ $? -ne 0 ]
then 
	vncserver :$screen_id
fi 
let "vnc_port = 5900 + screen_id"

#no-VNC restart 
myprint "Starting no-vnc (port: $no_vnc_PORT) pointing to VNC on port: $vnc_port"
for pid in `ps aux | grep "websockify" | grep -v "grep" | grep $vnc_port | awk '{print $2}'`
do 
	sudo kill -9 $pid 
done 
for pid in `ps aux | grep "launch.sh" | grep -v "grep" | awk '{print $2}'`
do 
	sudo kill -9 $pid 
done 
cd $no_vnc_path
(./utils/launch.sh --vnc localhost:$vnc_port --listen $no_vnc_PORT > $log_folder"/noVNC-log-"$no_vnc_PORT".txt" 2>&1 &)
cd - > /dev/null 2>71 

# export display 
export DISPLAY=:$screen_id

# stop if previously running 
for pid in `ps aux | grep 'scrcp\|scrcpy-server.jar' | grep -v "grep" | awk '{print $2}'`
do 
	sudo kill -9 $pid 
done

# iterate on connected devices
for device_id in `adb devices | grep -v List | cut -f 1`
do 
	opt="-s $device_id -m 640"
	if [ $record_screen == "True" ]
	then 
		suffix=`date +%s`
		opt=$opt" -r screen-record-$suffix.mp4"
	fi 

	# start screen mirroring in virtual screen 
	myprint "Starting device: $device_id"
	(sudo scrcpy $opt > $log_folder/log-$device_id-$session_id.txt 2>&1 &)
	sleep 3 
done 

# all done
url="http://localhost:$no_vnc_PORT/vnc-phone.html" 
myprint "Access device @URL: $url"
