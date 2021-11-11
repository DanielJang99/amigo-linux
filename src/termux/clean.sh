#!/bin/bash
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
sudo rm -rf logs 
mkdir logs
rm -rf mtrlogs
rm -rf website-testing-results
rm -rf speedtest-results
rm -rf cdnlogs
free_space=`df | grep "emulated" | awk '{print $4/(1000*1000)}'`
echo "[$0][`date`] Free space: $free_space"
