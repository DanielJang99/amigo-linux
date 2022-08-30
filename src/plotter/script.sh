#!/bin/bash

# params 
curr_path=`pwd`
exp_type='website-testing-results'; 
res="${curr_path}/DNS/"${exp_type}"/"

# create folder if needed
mkdir -p $res

# iterate on phones
for phone_dir in `ls`
do 
    log_file="${res}/phone-${phone_dir}.txt"
    if [ ! -d $phone_dir ]
    then 
        continue
    fi 
    cd $phone_dir'/'$exp_type    

    # iterate on folders
    for dir in `ls`
    do 
        if [ ! -d $dir ]
        then 
            continue
        fi 
        cd $dir
        # iterate on tshark files
        for f in `ls | grep "tshark"`
            do  zcat < $f | grep "DNS" | grep -v "MDNS" | awk -F ',' '{ip_src=$4; pkt_size=$NF; if(pkt_size>100){t_passed = $2 - t_sent; if(t_passed>0){print ip_src,t_passed*1000}}else{t_sent=$2;}}' >> $log
        done
        cd ..
    done
    cd ../..
    echo "Done with phone: " $phone_dir
    exit -1
done
