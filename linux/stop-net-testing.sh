#!/bin/bash
## NOTE:  Stop net-testing scripts
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-05-29

for pid in `ps aux | grep 'net-testing\|mtr.sh\|cdn-test.sh\|speedtest'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do 
	kill -9 $pid
done