#!/bin/bash

for pid in `ps aux | grep "socket-monitoring" | grep -v "grep" | awk '{print $2}'`
do  
    kill -9 $pid
done
