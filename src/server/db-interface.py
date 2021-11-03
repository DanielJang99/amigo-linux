#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
import time 
import json 
import sys
import psycopg2
import db_manager
from db_manager import run_query, insert_data, insert_command

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
	info = insert_command("prova", "*", time.time(), "adb shell ls")
	print(info)
	# invalidate a command (using command identifier)
#else:
	# insert data in database
	#info = insert_data(test_id, tester_id, location, timestamp, power_json, sense_json)
	#print(info)


