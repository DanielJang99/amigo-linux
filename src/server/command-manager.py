#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
import time 
import json 
import sys
import psycopg2
import psutil
import db_manager
import os 
from db_manager import run_query, insert_data, insert_command, insert_pi_command

## Eample to cleanup status updates
## python db-interface.py query "delete from status_update;"

## Example to return all status updates
## python db-interface.py query "select * from status_update"

## Eample to pause a command
## python db-interface.py query "UPDATE action_update SET status = 'pause' WHERE command_id = 'prova'"

# read input
if len(sys.argv) < 2:
	print("USAGE: " + sys.argv[1] + " opt [query/insert-command/ssh] [uid]")
	sys.exit(-1)
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
	info = insert_pi_command(command_id, "*", time.time(), "sudo input keyevent KEYCODE_HOME")
	print(info)
	# invalidate a command (using command identifier)
elif opt == "ssh":
	if len(sys.argv) < 2:
		print("USAGE: " + sys.argv[1] + " opt [query/insert-command/ssh] [uid]")
		sys.exit(-1)
	uid = sys.argv[2]
	curr_time = int(time.time())
	command_id = "root-" + str(curr_time)
	
	# use a new port
	if os.path.isfile('port.txt'):
		with open('port.txt', 'r') as f:
		    free_port = int(f.readline())
		free_port += 1 
	else: 
		free_port = 1025
	with open('port.txt', 'w') as f:
		f.write(str(free_port))
	info = insert_pi_command(command_id, uid, time.time(), "ssh -f -N -T -R " + str(free_port) + ":localhost:8022 root@23.235.205.53", str(10), "false")
	print(info)
