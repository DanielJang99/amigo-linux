#!/bin/bash
## Note:   Script for driving experiments
## Author: Matteo Varvello
## Date:   06/22/2021

# cleanup - make sure nothign is running 
cleanup(){
	command="sudo killall tcpdump"
	ssh -o StrictHostKeyChecking=no -p 12345 pi@$iot_proxy "$command"
	echo "[$0][`date +%s`] Stopped PCAP collection"
	command="killall python3"
	ssh -o StrictHostKeyChecking=no -p 12345 pi@$iot_proxy "$command"
	echo "[$0][`date +%s`] Stopped QUIC+ML server" 
}

# script usage
usage(){
    echo "==========================================================================================="
    echo "USAGE: $0 --id, --dur, --pcap, --clean, --start"
    echo "==========================================================================================="
    echo "--id         test identifier to be used" 
    echo "--dur        how long to run"
    echo "--pcap       flag to control pcap collection at the pi"
    echo "--clean      clean only"
    echo "--start      start server or not" 
    echo "==========================================================================================="
    exit -1
}

my_kill(){
    for pid in `ps aux | grep $1 | grep -v grep | awk '{print $2}'`
    do
        if [ $# -eq 2 ]
        then
            kill -SIGINT $pid
        else
            kill -9 $pid
        fi
    done
}

# general parameters
DURATION=86400                  # default test duration
test_id=`date +%s`              # unique test identifier 
pcap="false"                    # default do not collect traffic
iot_proxy="nj.batterylab.dev"   # address of iot proxy 
iot_port="7352"                 # port to be used 
use_quic="false"                # by default no quic is used 
use_random="false"              # by default no random durations or sleeps
clean_only="false"              # if enable, just cleanin ug
start_server="false"            # start server or not 

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        -h | --help)
            usage
            ;;
        --pcap)
            shift; pcap="true";  
			;;
        --id)
            shift; test_id="$1"; shift;  
			;;
        --dur)
            shift; DURATION="$1"; shift;  
			;;
        --start)
            shift; start_server="true";  
			;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# cleanup - make sure nothing is running 
if [ $start_server == "true" ] 
then 
	cleanup
	if [ $clean_only == "true" ] 
	then 
		echo "Cleanup done" 
		exit -1 
	fi 
fi 

# folder organization 
res_folder=`pwd`"/quic-results/$test_id"
mkdir -p $res_folder 
#qlogs_dir=`pwd`"/q-logs-internal/${test_id}/"
#mkdir -p $qlogs_dir	

# logging 
echo "[$0][`echo $(($(date +%s%N)/1000000))`]TestID:$test_id ResFolder:$res_folder IoT-Proxy:$iot_proxy:$iot_port"
 
# start quic server-side component 
if [ $start_server == "true" ] 
then 
	echo "[$0][`echo $(($(date +%s%N)/1000000))`] Starting IoT proxy (QUIC+ML)"
	ip_iot_proxy=`dig $iot_proxy | grep "ANSWER SECTION" -A 1 | grep -v ANSWER | awk '{print $NF}'`
	command="cd /home/pi/quic/aioquic && mkdir -p logs/$test_id && python3 -u examples/fiat_server.py --certificate tests/ssl_cert.pem --private-key tests/ssl_key.pem --port $iot_port --fiat-log logs/$test_id/fiat_server_$test_id.log --preprocess 0 > logs/$test_id/outlog_$test_id 2>&1"
	ssh -o StrictHostKeyChecking=no -p 12345 pi@$iot_proxy "$command" & 

	# collect pcap if requested
	if [ $pcap == "true" ] 
	then 
		echo "[$0][`echo $(($(date +%s%N)/1000000))`] Started PCAP collection"
		command="cd /home/pi/quic_iot/android/pcaps &&	sudo tcpdump -i wlan0 -w $test_id.pcap > /dev/null 2>&1"
		ssh  -o StrictHostKeyChecking=no -p 12345 pi@$iot_proxy "$command" & 
	fi 
fi 

# allow time for server to warmp up 
echo "allow time for server to warmp up - sleep 10..." 
sleep 10

# launch client
counter=1
t_start=`date +%s`
t_current=`date +%s`
let "t_p = t_current - t_start"
cd aioquic
while [ $t_p -lt $DURATION ]
do
	# zero RTT
	client_log="$res_folder/quic_client_zeroRTT_$counter.log"
	outlog="$res_folder/outlog_zeroRTT_$counter.log"
	echo "[$0][`echo $(($(date +%s%N)/1000000))`] Launching quic_client.py - zeroRTT" 
	(timeout 15 python3 -u examples/fiat_client.py --ca-certs tests/pycacert.pem https://$ip_iot_proxy:$iot_port/ --fiat-log $client_log --preprocess 0  --zero-rtt > $outlog 2>&1 &)
	sleep 5
	my_kill "fiat_client.py"
	
	# one RTT
	echo "sleep in between tests: sleep 5..." 
	sleep 5	
	client_log="$res_folder/quic_client_oneRTT_$counter.log"
	outlog="$res_folder/outlog_oneRTT_$counter.log"
	echo "[$0][`echo $(($(date +%s%N)/1000000))`] Launching quic_client.py - oneRTT" 
	(timeout 15 python3 -u examples/fiat_client.py --ca-certs tests/pycacert.pem https://$ip_iot_proxy:$iot_port/ --fiat-log $client_log --preprocess 0 > $outlog 2>&1 &)
	sleep 5	
	my_kill "fiat_client.py"
	let "counter ++"

    # update time passed 
	t_current=`date +%s`
    let "t_p = t_current - t_start"
done

# final cleanup 
cleanup 

# logging 
echo "All good!" 
