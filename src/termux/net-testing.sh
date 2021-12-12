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

# run NYU stuff 
# TODO 
#turn_device_on
# switch to 3G 
#am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
#tap_screen 370 765 1 
#tap_screen 370 765 1 
#tap_screen 370 660
#sudo input keyevent KEYCODE_BACK  

# switch back to 4G 
#am start -n com.qualcomm.qti.networksetting/com.qualcomm.qti.networksetting.MobileNetworkSettings
#tap_screen 370 765 1 
#tap_screen 370 765 1 
#tap_screen 370 560
#sudo input keyevent KEYCODE_BACK
#turn_device_off


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