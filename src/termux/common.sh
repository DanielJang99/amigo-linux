#!/bin/bash 
## Notes: Common functions across cripts 
## Author: Matteo Varvello (Brave Software)
## Date: 04/10/2019

# import util file
DEBUG=1
util_file=`pwd`"/util.cfg"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# absolute path 
curr_dir=`pwd`

# compute bandwidth consumed (delta from input parameter)
compute_bandwidth(){
	prev_traffic=$1
    
	# for first run, just report on current traffic	
	curr_traffic=`cat /proc/net/xt_qtaguid/stats | grep $interface | awk '{traffic += $6}END{print traffic}'`
    myprint "[INFO] Current traffic rx by $app: $curr_traffic"
    if [ -z $prev_traffic ]
    then
		traffic="-1"
		return -1
	fi 

    if [ -z $curr_traffic ]
    then
        myprint "[ERROR] Something went wrong in bandwidth calculcation"
		traffic="-1"
		return -1
	fi 
	traffic=`echo "$curr_traffic $prev_traffic" | awk '{traffic = ($1 - $2)/1000000; print traffic}'` #MB
	if [ -z $traffic ]
	then
		myprint "[ERROR] Something went wrong in traffic analysis"
		traffic=0
	fi
}

# monitor cpu
cpu_monitor(){
    sleep_time=3
    prev_total=0
    prev_idle=0
    first="true"
    stable=0
    started="false"
    t1=`date +%s`
    to_monitor="true"
	
	# logging 
	myprint "Start monitoring CPU (PID: $$)"
					
	# clean cpu sync barrier done via files 
	if [ -f ".ready_to_start" ] 
	then 
		rm ".ready_to_start"
	fi 

    # continuous monitoring
    while [ $to_monitor == "true" ]
    do
        result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
        cpu_util=`echo "$result" | cut -f 1 | cut -f 1 -d "%"`
        prev_idle=`echo "$result" | cut -f 2`
        prev_total=`echo "$result" | cut -f 3`
        t_current=`date +%s`
        let "time_passed = t_current - t1"
        if [ $first == "false" ]
        then
            echo -e $time_passed"\t"$result >> $log_cpu
        fi
        first="false"
        sleep $sleep_time
        to_monitor=`cat .to_monitor`
    done

    # logging
	myprint "Done monitoring CPU (PID: $$)"
}

# function to load package and activity info per supported browser
load_browser(){
	echo "load_browser"
    # FIXME -- path
    if [ ! -f $curr_dir"/browser-config.txt" ]
    then
        echo "[ERROR] File browser-config.txt is needed and it is missing"
        exit 1
    fi
    while read line
    do
        browser=`echo -e  "$line" | cut -f 1`
        package=`echo -e  "$line" | cut -f 2`
        activity=`echo -e "$line" | cut -f 3`
		echo "$browser $package $activity"
        dict_packages[$browser]=$package
        dict_activities[$browser]=$activity
    done < $curr_dir"/browser-config.txt"
}
