#!/data/data/com.termux/files/usr/bin/env bash
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
pkg install -y python
python -m pip install --upgrade pip

# install speedtest-cli    
pip install speedtest-cli    

# traffic collection 
pkg install -y tcpdump

# install tshark to analyze pcap traces 
pkg install -y tshark

# video analysis of web performance metrics
pkg install -y ffmpeg 
pip install wheel
pkg install -y imagemagick
echo "WARNING -- next command will take some time..."
pip install pillow 
#pip install pyssim     # skipping since takes forever and not needed? 
if [ ! -d "visualmetrics" ]
then
    git clone https://github.com/WPO-Foundation/visualmetrics
    cd visualmetrics
else
    cd visualmetrics
    git pull
fi
python visualmetrics.py --check

pkg install -y patchelf 
patchelf --replace-needed libxml2.so libxml2.so.2 /data/data/com.termux/files/usr/lib/libwireshark.so

# install jobs in crontab
crontab -r 
(crontab -l 2>/dev/null; echo "*/1 * * * * cd /data/data/com.termux/files/home/mobile-testbed/src/termux/ && ./need-to-run.sh > log-need-run") | crontab -
#(crontab -l 2>/dev/null; echo "0 2 * * * sudo reboot") | crontab -
# activate testing at certain time
#30 7 * * * echo "false" > "/data/data/com.termux/files/home/mobile-testbed/src/termux/.isDebug"

# make sure all permissions are granted 
sudo pm grant com.termux.api android.permission.READ_PHONE_STATE
sudo pm grant com.termux.api android.permission.ACCESS_FINE_LOCATION
sudo pm grant com.google.android.apps.maps android.permission.ACCESS_FINE_LOCATION
sudo pm grant com.example.sensorexample android.permission.ACCESS_FINE_LOCATION
sudo pm grant com.example.sensorexample android.permission.READ_PHONE_STATE

# accept termux wake lock 
termux-wake-lock
sleep 2 
# sudo input tap 587 832

# ensure that BT is enabled
bt_status=`sudo settings get global bluetooth_on`
if [ $bt_status -ne 1 ]
then
    echo "Activating BT"
    sudo service call bluetooth_manager 6
else
 	echo "BT is active: $bt_status"
fi 

# logging
echo "All DONE!"


# run one test 
#cd ../../termux
#mkdir -p logs 
#./state-update.sh test > logs/log-testing-`date +\%m-\%d-\%y_\%H:\%M`".txt" 2>&1

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
