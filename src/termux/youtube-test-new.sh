#!/data/data/com.termux/files/usr/bin/env bash
## NOTE: 1) get <<stats for nerds>> on youtube ; 2) manage Google account
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	myprint "Trapped CTRL-C"
	safe_stop
	exit -1 
}

safe_stop(){
	myprint "Entering safe stop..."
	sudo killall tcpdump
	close_all
}

# activate stats for nerds  
activate_stats_nerds(){
	myprint "Activating stats for nerds!!"
	sudo input tap 680 105 && sleep 0.2 && sudo input tap 680 105
	sleep 3
	tap_screen 370 1022 3
	#tap_screen 370 1125 1 #3
}


# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

# default parameters
DURATION=60                        # experiment duration
interface="wlan0"                  # default network interface to monitor (for traffic)
suffix=`date +%d-%m-%Y`            # folder id (one folder per day)
curr_run_id=`date +%s`             # unique id per run
res_folder="prova"
mkdir -p $res_folder
 
turn_device_on

# make sure SELinux is permissive
ans=`sudo getenforce`
myprint "SELinux: $ans"
if [ $ans == "Enforcing" ]
then
    myprint "Disabling SELinux"
    sudo setenforce 0
    sudo getenforce
fi

# clean youtube cache
base_folder="/data/data/com.google.android.youtube/"
if [ $1 == "all" ] 
then 
	myprint "Full youtube cleaning"
	sudo pm clear com.google.android.youtube
else 
	sudo mv $base_folder/ ./
	sudo pm clear com.google.android.youtube
	sudo mv com.google.android.youtube/ "/data/data/"
	myprint "Cleaning YT state"
	#sudo rm -rf $base_folder/app_dg_cache $base_folder/cache $base_folder/databases $base_folder/files $base_folder/no_backup $base_folder/files
fi 
#sudo rm -rf "${base_folder}/app_dg_cache"
#sudo rm -rf "${base_folder}/cache"
#sudo rm -rf "${base_folder}/cronet_metadata_cache"
#sudo rm -rf "${base_folder}/image_manager_disk_cache"
#sudo rm -rf "${base_folder}/volleyCache"
#sudo rm -rf "${base_folder}/gms_cache"
#sudo ls $base_folder

#myprint "Launching YT and allow to settle..."
#sudo monkey -p com.google.android.youtube 1 > /dev/null 2>&1 
#sleep 15

# make sure screen is in landscape 
myprint "Ensuring that screen is in portrait and auto-rotation disabled"
sudo  settings put system accelerometer_rotation 0 # disable (shows portrait) 
sudo  settings put system user_rotation 1          # put in landscape

pcap_file="${res_folder}/${curr_run_id}.pcap"
pcap6_file="${res_folder}/${curr_run_id}-6.pcap"
pcap_mix_file="${res_folder}/${curr_run_id}-mix.pcap"
tshark_file="${res_folder}/${curr_run_id}.tshark"
tshark6_file="${res_folder}/${curr_run_id}-6.tshark"
tshark_mix_file="${res_folder}/${curr_run_id}-mix.tshark"
sudo tcpdump -i $interface -w $pcap_file > /dev/null 2>&1 &
sudo tcpdump -i $interface -vv ip6 -w $pcap6_file > /dev/null 2>&1 &
sudo tcpdump -i $interface ip6 or ip -w $pcap_mix_file > /dev/null 2>&1 &
myprint "Started tcpdump: $pcap_file Interface: $interface"

# get initial network data information
compute_bandwidth
traffic_rx=$curr_traffic
traffic_rx_last=$traffic_rx

#launch test video
am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=TSZxxqHoLzE"

# allow to settle 
sleep 15

# activate stats for nerds  
myprint "Activating stats for nerds!!"
sudo input tap 1240 50 && sleep 0.2 && sudo input tap 1240 50
sleep 3
tap_screen 670 670 3

# attempt getting stats
tap_screen 1160 160 
termux-clipboard-get 

# wait for test to be done
sleep $DURATION

# stop playing (attempt)
myprint "Stop playing!"
sudo input keyevent KEYCODE_BACK
sleep 2 
tap_screen 1000 580

my_ip=`ifconfig $interface | grep "\." | grep -v packets | awk '{print $2}'`
my_ip_v6=`ifconfig $interface | grep "inet6" | head -n 1 | awk '{print $2}'`

sudo killall tcpdump
myprint "Stopped tcpdump. Starting tshark analysis"
tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
#tshark_size=`cat $tshark_file | awk -F "," -v my_ip=$my_ip '{if($4!=my_ip){if($8=="UDP"){tot_udp += ($NF-8);} if($8=="TCP"){tot_tcp += ($11);}}}END{tot=(tot_tcp+tot_udp)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000}'`
tshark_size=`cat $tshark_file | awk -F "," '{if($8=="UDP"){tot_udp += ($NF-8);} else if(index($8,"QUIC")!=0){tot_quic += ($NF-8);} else if($8=="TCP"){tot_tcp += ($11);}}END{tot=(tot_tcp+tot_udp+tot_quic)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000 " TOT-QUIC:" tot_quic/1000000}'`
echo $tshark_size

tshark -nr $pcap6_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark6_file
tshark_size=`cat $tshark6_file | awk -F "," '{if($8=="UDP"){tot_udp += ($NF-8);} else if(index($8,"QUIC")!=0){tot_quic += ($NF-8);} else if($8=="TCP"){tot_tcp += ($11);}}END{tot=(tot_tcp+tot_udp+tot_quic)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000 " TOT-QUIC:" tot_quic/1000000}'`
echo $tshark_size

tshark -nr $pcap_mix_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_mix_file
tshark_size=`cat $tshark_mix_file | awk -F "," '{if($8=="UDP"){tot_udp += ($NF-8);} else if(index($8,"QUIC")!=0){tot_quic += ($NF-8);} else if($8=="TCP"){tot_tcp += ($11);}}END{tot=(tot_tcp+tot_udp+tot_quic)/1000000; print "TOT:" tot " TOT-TCP:" tot_tcp/1000000 " TOT-UDP:" tot_udp/1000000 " TOT-QUIC:" tot_quic/1000000}'`
echo $tshark_size

sudo  settings put system user_rotation 0          # put in portrait
safe_stop

# update traffic rx
compute_bandwidth $traffic_rx_last
traffic_rx_last=$traffic_rx
myprint "[INFO] Traffic received: $traffic"
