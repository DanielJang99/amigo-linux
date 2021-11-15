#!/bin/bash
## NOTE: check if there is something to run 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/15/2021

# don't run if already running
debug=`cat .isDebug`
ps aux | grep "state-update.sh" | grep "bash" > .ps
N=`cat ".ps" | wc -l`
if [ $N -gt 0 -o $debug == "true" ] 
then 
	exit -1
fi 
./state-update.sh > logs/log-state-update-`date +\%m-\%d-\%y_\%H:\%M`.txt 2>&1 &
