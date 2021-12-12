#!/data/data/com.termux/files/usr/bin/env bash
# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

#logging 
echo "[`date`] net-testing START"

# folder organization
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
if [ $# -eq 3 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
fi  


#run NYU stuff 
echo "[`date`] starting NYU on 3G"
server_ip="212.227.209.11"
res_dir="zus-logs/$suffix"
mkdir -p $res_dir

#switch to 3G 
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
turn_device_on
am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
sleep 5 
tap_screen 370 765 5
tap_screen 370 765 5 
tap_screen 370 660 2
sudo input keyevent KEYCODE_BACK  
timeout 300 ./FTPClient $server_ip 8888 $uid 3G
if [ -f zeus.csv ]
then 
	mv zeus.csv "${res_dir}/${ts}-3G.txt"
fi 
turn_device_off

#switch back to 4G 
echo "[`date`] starting NYU on 4G"
turn_device_on
am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
sleep 5 
tap_screen 370 765 5
tap_screen 370 765 5
tap_screen 370 560 2
sudo input keyevent KEYCODE_BACK
turn_device_off
timeout 300 ./FTPClient $server_ip 8888 $uid 4G
if [ -f zeus.csv ]
then 
	mv zeus.csv "${res_dir}/${ts}-34.txt"
fi 

#############
exit -1 

# current free space 
free_space_s=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`

# run multiple MTR
./mtr.sh $suffix $t_s

# video testing with youtube -- SKIPPING, NOT RELIABLE
touch ".locked"
./youtube-test.sh --suffix $suffix --id $t_s --iface $iface --pcap --single
rm ".locked"
turn_device_off

# run a speedtest 
echo "[`date`] speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"
gzip "${res_folder}/speedtest-$t_s.json"

# run a speedtest in the browser (fast.com) -- having issue on this phone 
#./speed-browse-test.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s

# QUIC test? 
# TODO 

# test multiple webages
touch ".locked"
./web-test.sh  --suffix $suffix --id $t_s --iface $iface --pcap
rm ".locked"

# safety cleanup 
sudo pm clear com.android.chrome
#sudo pm clear com.google.android.youtube
close_all
sudo killall tcpdump
for pid in `ps aux | grep 'youtube-test\|web-test\|mtr.sh\|cdn-test.sh\|speedtest-cli'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do
    kill -9 $pid
done
turn_device_off

# current free space 
free_space_e=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
space_used=`echo "$free_space_s $free_space_e" | awk '{print($1-$2)*1000}'`

#logging 
echo "[`date`] net-testing END. FreeSpace: ${free_space_e}GB SpaceUsed: ${space_used}MB"