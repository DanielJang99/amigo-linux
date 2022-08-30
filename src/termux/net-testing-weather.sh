#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: net testing during weather issues (for now basic, aka no browsing or other just low level stuff)
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/3/2021

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	./stop-net-testing.sh
}

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "mobile_IP":"${mobile_ip}",
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "net":"${net}",
    "mServiceState":"${mServiceState}",
    "data_Used":"${data_used}",        
    "msg":"${msg}"
    }
EOF
}


# params
MAX_LOCATION=5              # timeout of duration command
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
opt="long"
if [ $# -eq 4 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
	opt=$4
fi  

# retrieve last used server port 
if [ -f ".server_port" ] 
then 
	SERVER_PORT=`cat ".server_port"`
else 
	SERVER_PORT="8082"
fi 

#logging 
free_space_s=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
t_start=`date +%s`
echo "[`date`] net-testing-weather $opt START. SERVER_PORT:$SERVER_PORT -- FreeSpace: $free_space"

# run multiple MTR
timeout 300 ./mtr.sh $suffix $t_s

# run a speedtest 
myprint "Running speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
timeout 300 speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"
gzip "${res_folder}/speedtest-$t_s.json"
myprint "Sleep 30 to lower CPU load..."
sleep 30  		 

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# test multiple CDNs
timeout 300 ./cdn-test.sh $suffix $t_s

# safety cleanup 
close_all
sudo killall tcpdump
for pid in `ps aux | grep 'youtube-test\|web-test\|mtr.sh\|cdn-test.sh\|speedtest-cli'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do
    kill -9 $pid
done
rm ".locked"
turn_device_off

# current free space 
free_space_e=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
space_used=`echo "$free_space_s $free_space_e" | awk '{print($1-$2)*1000}'`

#logging 
t_end=`date +%s`
let "t_p = t_end - t_start"
echo "[`date`] net-testing $opt END. Duration: $t_p FreeSpace: ${free_space_e}GB SpaceUsed: ${space_used}MB"