#!/data/data/com.termux/files/usr/bin/bash
suffix=`date +%d-%M-%Y`
res_dir="pinglogs/$suffix"
ts=`date +%s`
num=10
mkdir -p $res_dir

# popular providers
sudo mtr -rwc $num google.com   >  $res_dir/google-$ts.txt 2>&1
exit -1 
sudo mtr -rwc $num facebook.com >  $res_dir/facebook-$ts.txt  2>&1
sudo mtr -rwc $num amazon.com   >  $res_dir/amazon-$ts.txt 2>&1

#DNS 
sudo mtr -rwc $num 8.8.8.8 > $res_dir/google-dns-$ts.txt 2>&1
sudo mtr -rwc $num 1.1.1.1 > $res_dir/cloudflare-dns-$ts.txt 2>&1
#sudo mtr -rwc $num 8.8.8.8 > $res_dir/ 2>&1
