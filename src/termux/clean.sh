#!/data/data/com.termux/files/usr/bin/bash
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
sudo rm -rf logs 
sudo rm -rf mtrlogs
sudo rm -rf website-testing-results
sudo rm -rf speedtest-results
sudo rm -rf cdnlogs
sudo rm -rf locationlogs
sudo rm -rf speedtest-cli-logs
sudo rm -rf data 
sudo rm -rf videoconferencing
sudo rm -rf youtube-results
sudo rm -rf zus-logs
sudm rm -rf wifi-info
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
