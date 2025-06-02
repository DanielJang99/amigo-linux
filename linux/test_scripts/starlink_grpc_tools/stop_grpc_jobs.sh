#!/bin/bash
## NOTE:  Stop starlink grpc jobs
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-06-02

for pid in `ps aux | grep 'dish_grpc_text.py status'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do 
	kill -9 $pid
done

for pid in `ps aux | grep 'get_obstruction_raw.py'  | grep -v "grep" | grep -v "stop" | awk '{print $2}'`
do 
	kill -9 $pid
done


