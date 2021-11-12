#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
import time 
import json 
import sys
import psycopg2
import db_manager
from db_manager import run_query, insert_data, insert_command, insert_pi_command

## Eample to cleanup status updates
## python db-interface.py query "delete from status_update;"

## Example to return all status updates
## python db-interface.py query "select * from status_update"

## Eample to pause a command
## python db-interface.py query "UPDATE action_update SET status = 'pause' WHERE command_id = 'prova'"

# read input
opt = sys.argv[1]

# switch among supported operations
if opt == "query":
	# run a query 
	query = sys.argv[2]
	print("QUERY:", query)
	info, msg  = run_query(query)
	print("INFO:", info)
	print("MSG", msg)

elif opt == "insert-command":
	# insert command in database
	curr_time = int(time.time())
	command_id = "matteo-" + str(curr_time)
	#info = insert_pi_command(command_id, "*", time.time(), "adb -s c95ad2777d56 shell \"input keyevent KEYCODE_HOME\"")
	#info = insert_pi_command(command_id, "*", time.time(), "sudo input keyevent KEYCODE_HOME")
	info = insert_pi_command(command_id, "*", time.time(), "ssh -f -N -T -R 8022:localhost:8022 root@23.235.205.5")
	#info = insert_pi_command(command_id, "*", time.time(), "adb -s c95ad2777d56 shell am start -n com.android.chrome/com.google.android.apps.chrome.Main -d https://www.repubblica.it")
	print(info)
	# invalidate a command (using command identifier)
#else:
	# insert data in database
	#info = insert_data(test_id, tester_id, location, timestamp, power_json, sense_json)
	#print(info)


