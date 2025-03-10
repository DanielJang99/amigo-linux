#!/data/data/com.termux/files/usr/bin/bash
## Date: 10/14/2024
## Author: Daniel Jang (hsj276@nyu.edu)
## NOTE: script to validate Airalo findings with MTR tests


# import common file
common_file=`pwd`"/common.sh"
if [ -f $common_file ]
then
	source $common_file
else
	echo "Common file $common_file is missing"
	exit -1
fi

# import utilities files needed
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

# helper to run a test 
test(){
	prefix=$2
	myprint "Testing $prefix"

	sudo mtr -r4wc $num $1  >  $res_dir/$prefix-ipv4-$ts-$network_ind.txt 2>&1
	gzip $res_dir/$prefix-ipv4-$ts-$network_ind.txt
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

network_type=`get_network_type`
network_ind=`echo $network_type | cut -f 1 -d "_"`

# folder organization
res_dir="mtrlogs/$suffix"
mkdir -p $res_dir
num=10

# logging
myprint "Starting MTR reporting..."

# popular providers
test fjr04s06-in-f14.1e100.net google_uae
test lhr25s33-in-f14.1e100.net google_uk
test mia09s26-in-f14.1e100.net google_miami
test google.com google 
test edge-star-mini-shv-04-sin6.facebook.com facebook_singapore
test edge-star-mini-shv-02-lhr8.facebook.com facebook_uk
test edge-star-mini-shv-01-doh1.facebook.com facebook_doha
test edge-star-mini-shv-02-lga3.facebook.com facebook_nj
test facebook.com facebook

# logging 
t_e=`date +%s`
let "t_p = t_e - t_s"
myprint "Done MTR reporting. Duration: $t_p. ResFolder: $res_dir"