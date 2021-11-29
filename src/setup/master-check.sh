#!/bin/bash

res_folder="./check-results/"`date +%d-%m-%Y`
mkdir -p $res_folder
for device in `cat device-list  | grep Prepped | cut -f 3`
do 
	timeout 600 ./check-update.sh $device > $res_folder"/"$device
done
