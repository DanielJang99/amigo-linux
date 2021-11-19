#!/bin/bash

for pid in `ps aux | grep 'state\|net-testing\|web-test'  | grep -v grep | awk '{print $2}'`
do 
	kill -9 $pid
done
