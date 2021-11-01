#!/bin/bash
DURATION=86400
interval=5
suffix=`date +%s`
if [ $# -eq 1 ] 
then 
	suffix=$1
fi 
res_dir="pinglogs/$suffix"
mkdir -p $res_dir
t_start=`date +%s`
t_current=`date +%s`
let "t_p = t_current - t_start"
while [ $t_p -lt $DURATION ]
do
	t_s_ping=`date +%s`
	ans=`timeout 5 ping -c 1 "google.com" | grep "icmp_seq"`
	echo -e "`date +%s`\t$ans" >> $res_dir/log-google-$suffix.txt
	ans=`timeout 5 ping -c 1 "www.microsoft.com" | grep "icmp_seq"`
	echo -e "`date +%s`\t$ans" >> $res_dir/log-microsoft-$suffix.txt
	ans=`timeout 5 ping -c 1 "amazon.com" | grep "icmp_seq"`
	echo -e "`date +%s`\t$ans" >> $res_dir/log-amazon-$suffix.txt
	t_current=`date +%s`
	let "t_sleep = interval - (t_current - t_s_ping)"
	if [ $t_sleep -gt 0 ] 
	then 
		echo "Sleeping for $t_sleep"
		sleep $t_sleep
	fi 
	t_current=`date +%s`
	let "t_p = t_current - t_start"
done
