#!/data/data/com.termux/files/usr/bin/bash
## Note:   Script for driving experiments
## Author: Matteo Varvello
## Date:   06/22/2021

# script usage
usage(){
    echo "==========================================================================================="
    echo "USAGE: $0 --id, --dur"
    echo "==========================================================================================="
    echo "--id         test identifier to be used" 
    echo "--dur        how long to run"
    echo "==========================================================================================="
    exit -1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
	echo "Trapped CTRL-C"
	exit -1 
}

# general parameters
DURATION=86400                  # default test duration
test_id=`date +%s`              # unique test identifier 
interval=5

# read input parameters
while [ "$#" -gt 0 ]
do
    case "$1" in
        -h | --help)
            usage
            ;;
        --id)
            shift; test_id="$1"; shift;  
			;;
        --dur)
            shift; DURATION="$1"; shift;  
			;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
    esac
done

# folder organization 
res_folder=`pwd`"/quic-results-external/$test_id"
mkdir -p $res_folder 

# logging 
echo "[$0] TestID:$test_id ResFolder:$res_folder"

# load urls to be tested
url_file="quic-sites.txt"
num_urls=0
while read line
do
    urlList[$num_urls]="$line"
	id=`echo $line | md5sum | cut -f1 -d " "`
	echo "[$0] URL: $line ID: $id" 
    let "num_urls++"
done < $url_file
 
# start testing
t_start=`date +%s`
t_current=`date +%s`
let "t_p = t_current - t_start"
counter=0
while [ $t_p -lt $DURATION ]
do
	t_s=`date +%s`
	for((i=0; i<num_urls; i++))
	do 
	    url=${urlList[$i]}
		id=`echo $url | md5sum | cut -f1 -d " "`
		log_file=$res_folder"/"$id
		qlogs_dir=`pwd`"/q-logs/${test_id}/${id}/"
		mkdir -p $qlogs_dir
		timeout 15 python3 aioquic/examples/http3_client.py $url --quic-log $qlogs_dir >> $log_file 2>&1
		qlog_file=`ls -r $qlogs_dir | tail -n 1`
		mv $qlogs_dir"/"$qlog_file  $qlogs_dir"/qlog-$counter.qlog" 
	done
    t_current=`date +%s`
    let "t_sleep = interval - (t_current - t_s)"
    if [ $t_sleep -gt 0 ]
    then
        sleep $t_sleep
    fi	

    # update time passed 
	t_current=`date +%s`
    let "t_p = t_current - t_start"
	let "counter++"
	val=$(($counter % 10))
	if [ $val -eq 0 ] 
	then 
		echo "TimePassed: $t_p sec Counter:$counter"
	fi 
done

# logging 
echo "All good!" 
