#!/bin/bash
## Make sure device mirroring is off by default
## Author: Matteo Varvello
## Date: 10/21/2019

# general parameters
screen_id=3  # default  (virtual) display ID
let "vnc_port = 5900 + screen_id"

# stop VNC
echo "Stopping VNC. Screen: $screen_id"
vncserver -kill :$screen_id

#stopping no-VNC
echo "Stopping noVNC..."
for pid in `ps aux | grep "websockify" | grep -v "grep" | grep $vnc_port | awk '{print $2}'`; do kill -9 $pid; done
for pid in `ps aux | grep "launch.sh" | grep -v "grep" | awk '{print $2}'`; do	kill -9 $pid; done

# stop if previously running
echo "Stopping any scrcp process..."
for pid in `ps aux | grep 'scrcp\|scrcpy-server.jar' | grep -v "grep" | awk '{print $2}'`; do kill -9 $pid; done

# stop web-app
echo "Stopping web-app..."
for pid in `ps aux | grep "web-app.py" | grep -v "grep" | awk '{print $2}'`; do  kill -9 $pid; done
