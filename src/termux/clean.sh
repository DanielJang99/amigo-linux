#!/data/data/com.termux/files/usr/bin/bash
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
sudo rm -rf logs 
rm -rf mtrlogs
rm -rf website-testing-results
rm -rf speedtest-results
rm -rf cdnlogs
rm -rf locationlogs
rm -rf speedtest-cli-logs
rm -rf data 
rm -rf videoconferencing
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
