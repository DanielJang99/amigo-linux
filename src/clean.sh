#!/bin/bash
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
sudo rm -rf logs 
mkdir logs
cd pi 
sudo rm -rf pinglogs
mkdir pinglogs
sudo rm -rf cdnlogs
mkdir cdnlogs
sudo rm -rf quic-results-external
mkdir -p quic-results-external
sudo rm -rf quic-results
mkdir -p quic-results
sudo rm -rf q-logs
mkdir -p q-logs
cd ../android
sudo rm -rf website-testing-results
mkdir website-testing-results
sudo rm -rf speedtest-results
mkdir speedtest-results
free_space=`df | grep root | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
