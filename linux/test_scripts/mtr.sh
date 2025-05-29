#!/bin/bash
## NOTE:  MTR adapted for Linux containers
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-05-29

# import util file
DEBUG=1
util_file=`pwd`"/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# mtr to service providers  
test(){
	prefix=$2
	myprint "Testing $prefix"
    test_start_time=`date +%s`
	sudo mtr -r4wc $num $1  >  $res_dir/$prefix-ipv4-$test_start_time-$network_ind.txt 2>&1
    test_end_time=`date +%s`
    test_duration=$((test_end_time - test_start_time))
    myprint "$prefix ipv4 MTR start: $test_start_time, end: $test_end_time, duration: $test_duration seconds"
	gzip $res_dir/$prefix-ipv4-$test_start_time-$network_ind.txt
	ping6 -c 3 $1 > /dev/null 2>&1
	if [ $? -eq 0 ] 
	then
        test_start_time=`date +%s`
		sudo mtr -r6wc $num $1   >  $res_dir/$prefix-ipv6-$test_start_time-$network_ind.txt 2>&1
        test_end_time=`date +%s`
        test_duration=$((test_end_time - test_start_time))
        myprint "$prefix ipv6 MTR start: $test_start_time, end: $test_end_time, duration: $test_duration seconds"
		gzip $res_dir/$prefix-ipv6-$test_start_time-$network_ind.txt 
	fi 
}

# mtr to DNS providers
test_dns() {
    provider=$1
    ip4=$2
    ip6=$3
    
    test_start_time=`date +%s`
    sudo mtr -r4wc $num $ip4 > $res_dir/$provider-dns-ipv4-$test_start_time-$network_ind.txt 2>&1
    test_end_time=`date +%s`
    test_duration=$((test_end_time - test_start_time))
    myprint "$provider-dns-ipv4 MTR start: $test_start_time, end: $test_end_time, duration: $test_duration seconds"
    gzip $res_dir/$provider-dns-ipv4-$test_start_time-$network_ind.txt
    
    test_start_time=`date +%s`
    sudo mtr -r6wc $num $ip6 > $res_dir/$provider-dns-ipv6-$test_start_time-$network_ind.txt 2>&1
    test_end_time=`date +%s`
    test_duration=$((test_end_time - test_start_time))
    myprint "$provider-dns-ipv6 MTR start: $test_start_time, end: $test_end_time, duration: $test_duration seconds"
    gzip $res_dir/$provider-dns-ipv6-$test_start_time-$network_ind.txt
}

# input
if [ $# -eq 2 ]
then 
	suffix=$1
	ts=$2
else 
	suffix=`date +%d-%m-%Y`
	ts=`date +%s`
fi 

network_type=$(check_network_status)
network_ind=$(echo "$network_type" | cut -f1 -d"_")

# folder organization
res_dir="results/mtrlogs/$suffix/$ts"
mkdir -p $res_dir
num=10

# logging
myprint "Starting MTR reporting..."

# popular providers
test google.com google 
test facebook.com facebook
test amazon.com amazon

# popular DNS
test_dns google 8.8.8.8 2001:4860:4860::8888
test_dns cloudflare 1.1.1.1 2606:4700:4700::1111


t_e=`date +%s`
let "t_p = t_e - t_s"
myprint "Done MTR reporting. Duration: $t_p. ResFolder: $res_dir"
