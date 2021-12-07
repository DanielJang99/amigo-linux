#!/bin/bash

res_folder="./check-results/"`date +%d-%m-%Y`
mkdir -p $res_folder
c=0
while read line
do 
	devices[$c]=$line
	let "c++"
done < $1
for((i=0; i<$c; i++))
do 
	curr_device=${devices[$i]}
	echo "timeout 1800 ./check-update.sh $curr_device > $res_folder"/"$curr_device &"
done
