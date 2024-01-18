#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 1/18/2024

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
	turn_device_on
	close_all
}

start_pcap(){
    pcap_file="${res_dir}/${run_id}.pcap"
    sudo tcpdump -i $interface ip6 or ip -w $pcap_file > /dev/null 2>&1 & 
    myprint "Started tcpdump: $pcap_file Interface: $interface"
    sleep 1
}

end_pcap(){
    tshark_file="${res_dir}/${run_id}.tshark"
    sudo killall tcpdump
    tshark -nr $pcap_file -T fields -E separator=',' -e frame.number -e frame.time_epoch -e frame.len -e ip.src -e ip.dst -e ipv6.dst -e ipv6.src -e _ws.col.Protocol -e tcp.srcport -e tcp.dstport -e tcp.len -e tcp.window_size -e tcp.analysis.bytes_in_flight  -e tcp.analysis.ack_rtt -e tcp.analysis.retransmission  -e udp.srcport -e udp.dstport -e udp.length > $tshark_file
    sudo rm $pcap_file
}

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file

t_s=`date +%s`
interface="wlan0"

# input
if [ $# -eq 2 ]
then 
	suffix=$1
	ts=$2
else 
	suffix=`date +%d-%m-%Y`
	ts=`date +%s`
fi 

res_dir="latency_logs/$suffix"
mkdir -p $res_dir

# run ping to google.com (icmp packet)
run_id="ping-$ts"
ping_output="${res_dir}/${run_id}.txt"
start_pcap 
ping -c 5 -W 2 www.google.com > $ping_output
avg_ping=`cat $ping_output | grep "mdev" | cut -f 2 -d "=" | cut -f 2 -d "/"`
echo "google avg_ping: $avg_ping"
end_pcap


# run nping to google.com (tcp packet) 
run_id="nping-$ts"
nping_output="${res_dir}/${run_id}.txt"
start_pcap
nping -c 5 www.google.com > $nping_output
avg_nping=`cat $nping_output | grep "Avg rtt" | cut -f 4 -d ":" | cut -f 1 -d "m" | cut -f 2 -d " "` 
echo "google avg_nping: $avg_nping"
end_pcap


# traceroute to google.com (icmp packet)
run_id="tr-icmp-$ts"
tr_output="${res_dir}/${run_id}.txt"
start_pcap
traceroute --icmp www.google.com > $tr_output 
end_pcap


# traceroute to google.com (tcp/udp packet)
run_id="tr-tcp-$ts"
tr_output="${res_dir}/${run_id}.txt"
start_pcap
traceroute www.google.com > $tr_output 
end_pcap

t_e=`date +%s`
let "t_p = t_e - t_s"
myprint "Done Latency reporting. Duration: $t_p. ResFolder: $res_dir"

