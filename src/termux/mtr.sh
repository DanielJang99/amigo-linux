#!/data/data/com.termux/files/usr/bin/bash

test(){
	num=10
	prefix=$2
	sudo mtr -r4wc $num $1  >  $res_dir/$prefix-ipv4-$ts.txt 2>&1
	ping6 -c 3 $1 > /dev/null 2>&1
	if [ $? -eq 0 ] 
	then 
		sudo mtr -r6wc $num $1   >  $res_dir/$prefix-ipv6-$ts.txt 2>&1
	fi 
}

suffix=`date +%d-%m-%Y`
res_dir="pinglogs/$suffix"
ts=`date +%s`
mkdir -p $res_dir
t_s=`date +%s`
echo "Starting MTR reporting..."

# popular providers
test google.com google 
test facebook.com facebook
test amazon.com amazon

# popular DNS
test 8.8.8.8 google-dns
test 1.1.1.1 cloudflare-dns
#sudo mtr -rwc $num 8.8.8.8 > $res_dir/ 2>&1

# logging 
t_e=`date +%s`
let "t_p = t_e - t_s"
echo "Done MTR reporting. Duration: $t_p"
