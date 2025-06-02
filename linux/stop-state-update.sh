#!/bin/bash
## NOTE:  Stop state-update.sh
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-06-02

for pid in `ps aux | grep 'state-update.sh'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do 
	kill -9 $pid
done