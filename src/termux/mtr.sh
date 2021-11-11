#!/data/data/com.termux/files/usr/bin/bash
## Date: 11/11/2021
## Author: Matteo Varvello (varvello@gmail.com)
## NOTE: script to run bunch of mtr tests (both ipv4 and ipv6)

# helper to run a test 
test(){
	prefix=$2
	sudo mtr -r4wc $num $1  >  $res_dir/$prefix-ipv4-$ts.txt 2>&1
	ping6 -c 3 $1 > /dev/null 2>&1
	if [ $? -eq 0 ] 
	then 
		sudo mtr -r6wc $num $1   >  $res_dir/$prefix-ipv6-$ts.txt 2>&1
	fi 
}

# folder organization
suffix=`date +%d-%m-%Y`
res_dir="mtrlogs/$suffix"
mkdir -p $res_dir
num=10

# logging
t_s=`date +%s`
echo "Starting MTR reporting..."

# popular providers
test google.com google 
test facebook.com facebook
test amazon.com amazon

# popular DNS
sudo mtr -r4wc $num 8.8.8.8 >  $res_dir/google-dns-ipv4-$ts.txt 2>&1
sudo mtr -r6wc $num 82001:4860:4860::888 >  $res_dir/google-dns-ipv6-$ts.txt 2>&1
sudo mtr -r4wc $num 1.1.1.1 >  $res_dir/cloudflare-dns-ipv4-$ts.txt 2>&1
sudo mtr -r6wc $num 2606:4700:4700::1111 >  $res_dir/cloudflare-dns-ipv6-$ts.txt 2>&1

# logging 
t_e=`date +%s`
let "t_p = t_e - t_s"
echo "Done MTR reporting. Duration: $t_p. ResFolder: $res_dir"
