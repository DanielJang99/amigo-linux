#!/bin/bash
scp web-app.py nyu:temp-server && ssh nyu "cd temp-server; ./restart.sh"
sleep 2 
curl -H "Content-Type: application/json" --data '{"data":"testing data"}' https://mobile.batterylab.dev:8082/status
