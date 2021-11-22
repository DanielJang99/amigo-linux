#!/bin/bash
# upgrade 
pkg upgrade -y 

# install termux API
pkg install -y termux-api

# install sudo 
pkg install -y tsu

# install and setup vim (just in case)
pkg install -y vim
# TODO 

# install mtr 
pkg install -y root-repo
pkg install -y mtr

# install python and upgrade pip 
pkg install -y python3
python -m pip install --upgrade pip

# install speedtest-cli    
pip install speedtest-cli    

# traffic collection 
pkg install -y tcpdump

# video analysis of web performance metrics
pkg install -y ffmpeg 
pip install wheel
pkg install -y imagemagick
echo "WARNING -- next command will take some time..."
pip install pillow 
#pip install pyssim     # skipping since takes forever and not needed? 
git clone https://github.com/WPO-Foundation/visualmetrics
cd visualmetrics
python visualmetrics.py --check

# install crontab and add our jobs 
pkg install -y cronie
(crontab -l 2>/dev/null; echo "*/3 * * * * cd /data/data/com.termux/files/home/mobile-testbed/src/termux/ && ./need-to-run.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * cd sudo reboot") | crontab -
# activate testing at certain time
#30 7 * * * echo "false" > "/data/data/com.termux/files/home/mobile-testbed/src/termux/.isDebug"

# make sure all permissions are granted 
sudo pm grant com.termux.api android.permission.READ_PHONE_STATE
sudo pm grant com.google.android.apps.maps android.permission.ACCESS_FINE_LOCATION

# run one test 
cd ../termux
./state-update.sh test

############################ TESTING, TO BE DECIDED 
# aioquic 
# pkg install rust
# pip install wheel # TOBETESTED
# git clone git@github.com:aiortc/aioquic.git
# cd aioquic 
# pip install -e .
# pip install asgiref dnslib httpbin starlette wsproto


#pkg install miniupnpc
#pkg install iperf3
#pkg install wpa-supplicant
#pkg install wireless-tools
