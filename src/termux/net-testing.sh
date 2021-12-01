#!/data/data/com.termux/files/usr/bin/bash
# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

#logging 
echo "[`date`] net-testing START"

# folder organization
suffix=`date +%d-%m-%Y`
t_s=`date +%s`
iface="wlan0"
if [ $# -eq 2 ] 
then
	suffix=$1
	t_s=$2
	iface=$3
fi  

# run a speedtest 
echo "[`date`] speedtest-cli..."
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"

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


# run multiple MTR
./mtr.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s

# QUIC test? 
# TODO 

# test multiple webages
turn_device_on
touch ".locked"
./web-test.sh  --suffix $suffix --id $t_s --iface $iface

# video testing - skipping for now
./youtube-test.sh --suffix $suffix --id $t_s --iface $iface

# save battery, screen off 
turn_device_off
rm ".locked"

#logging 
echo "[`date`] net-testing END"
