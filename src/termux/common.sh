#!/data/data/com.termux/files/usr/bin/bash
## Notes: Common functions across cripts 
## Author: Matteo Varvello (Nokia)
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
	#curr_traffic=`cat /proc/net/xt_qtaguid/stats | grep $interface | awk '{traffic += $6}END{print traffic}'`
	curr_traffic=`ifconfig $interface | grep "RX" | grep "bytes" | awk '{print $(NF-2)}'`
    myprint "[INFO] Current traffic rx: $curr_traffic"
    if [ -z $prev_traffic ]
    then
		traffic="-1"
		return -1
	fi 
    if [ -z $curr_traffic ]
    then
        myprint "[ERROR] Something went wrong in bandwidth calculation"
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

# monitor CPU usage using TOP
cpu_monitor_top(){
    sleep_time=3
    to_monitor="true"
    if [ $app == "zoom" ]
    then
        key="zoom"
    elif [ $app == "meet" ]
    then
        key="com.google.and"
    elif [ $app == "webex" ]
    then
        key="webex"
    elif [ $app == "youtube" ]
    then
        key="android.youtube"
    elif [ $app == "chrome" ]
    then
        key="android.chrome"
    elif [ $app == "brave" ]
    then
        key="brave"
    fi

    # logging
    myprint "Start monitoring CPU via TOP (PID: $$)"

    # continuous monitoring
    while [ $to_monitor == "true" ]
    do
        sudo top -n 1 | grep $key | grep -v "grep" >> $log_cpu_top
        #sudo top -n 2 | grep $key | grep -v "grep" >> $log_cpu_top
		#sleep 1 
        sleep $sleep_time
        to_monitor=`cat .to_monitor`
    done

    # logging
    myprint "Done monitoring CPU via TOP (PID: $$)"
}


# monitor CPU assuming background process doing so is there
cpu_monitor(){
    sleep_time=3
    to_monitor="true"
    if [ -f ".cpu-usage" ]
    then 
        myprint "Started saving CPU values to $log_cpu"        
        while [ $to_monitor == "true" ]
        do
            val=`cat .cpu-usage`
            curr_time=`date +%s`
            echo -e $curr_time"\t"$val >> $log_cpu
            sleep $sleep_time
            to_monitor=`cat .to_monitor`    
        done
        myprint "Stopped saving CPU values to $log_cpu"
        gzip $log_cpu
    else 
        myprint "Background process monitoring CPU not found"
    fi 
}


# monitor cpu
cpu_monitor_old(){
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
