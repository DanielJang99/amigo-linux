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
import time 
import datetime

## Eample to cleanup status updates
## python db-interface.py query "delete from status_update;"

## Example to return all status updates
## python db-interface.py query "select * from status_update"

## Eample to pause a command
## python db-interface.py query "UPDATE action_update SET status = 'pause' WHERE command_id = 'prova'"

# read input
if len(sys.argv) < 2:
	print("USAGE: " + sys.argv[0] + " opt [ssh/update/restart/wifi/generic] [uid-list] [command]")
	sys.exit(-1)
opt = sys.argv[1]

# switch among supported operations
#if opt == "query":
#	# run a query 
#	query = sys.argv[2]
#	print("QUERY:", query)
#	info, msg  = run_query(query)
#	print("INFO:", info)
#	print("MSG", msg)
curr_time = int(time.time())
command_id = "root-" + str(curr_time)
uid_list = ["*"]
if opt == "ssh":
	if len(sys.argv) < 3:
		print("USAGE: " + sys.argv[1] + " opt [query/insert-command/ssh] [uid-list]")
		sys.exit(-1)
	uid_list = sys.argv[2].split(',')
	
	# use a new port
	if os.path.isfile('port.txt'):
		with open('port.txt', 'r') as f:
		    free_port = int(f.readline())
		free_port += 1 
	else: 
		free_port = 1025
	with open('port.txt', 'w') as f:
		f.write(str(free_port))
	info = insert_pi_command(command_id, uid_list, time.time(), "ssh -i ~/.ssh/id_rsa_mobile -o StrictHostKeyChecking=no -f -N -T -R " + str(free_port) + ":localhost:8022 root@23.235.205.53", str(10), "false")
	print(info)
	print("Check on DB when ready. Then connect to tunnel with:")
	print("ssh -oStrictHostKeyChecking=no -i id_rsa_mobile -p " + str(free_port) + " localhost")
elif opt == "package":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested package update for devices:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "git pull && /data/data/com.termux/files/home/mobile-testbed/src/setup/package-check.sh > \".log-package-check\" 2>&1", str(600), "false")
elif opt == "update":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested code update for device:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "git pull", str(30), "false")
elif opt == "enable-zoom":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested to enable zoom for devices:", uid_list)
	#info = insert_pi_command(command_id, uid_list, time.time(), "git pull && ./zoom-enable.sh  -a zoom -m 6893560343 -p m06Yb9", str(120), "false") # USC
	info = insert_pi_command(command_id, uid_list, time.time(), "git pull && ./zoom-enable.sh  -a zoom -m 8128761187 -p E4zE4q", str(120), "false") # UK
elif opt == "location-update":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested network location update for devices:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "termux-location -p network -r last", str(30), "false")
elif opt == "net-start":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested code restart network experiment for devices:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "echo \"true\" > \".net_status\"", str(10), "false")
elif opt == "restart":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested code restart for devices:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "echo \"false\" > \".status\"", str(10), "false")
elif opt == "stop":
	if len(sys.argv) == 3:
		uid_list = sys.argv[2].split(',')
	print("Requested STOP for devices:", uid_list)
	info = insert_pi_command(command_id, uid_list, time.time(), "echo \"true\" > \".isDebug\" && echo \"false\" > \".status\"", str(10), "false") # this stops monitor script 
	#time.sleep(5)
	#info = insert_pi_command(command_id, uid_list, time.time(), "echo \"false\" > \".status\"", str(10), "false")
elif opt == "wifi":
	if len(sys.argv) != 4:
		print("USAGE: " + sys.argv[1] + " wifi <uid_list> <command>")
		sys.exit(-1)
	uid_list = sys.argv[2].split(',')
	switch  = sys.argv[3]
	if switch == "enable": 
		command = "termux-wifi-enable true"
	elif switch == "disable":
		command = "termux-wifi-enable false"
	else: 
		print("ERROR")
		sys.exit(-1)
	info = insert_pi_command(command_id, uid_list, time.time(), command, str(10), "false")
	print(info)
elif opt == "generic":
	if len(sys.argv) != 4:
		print(len(sys.argv))
		print("USAGE: " + sys.argv[1] + " <generic> <uid_list> <command>")
		sys.exit(-1)
	uid_list = sys.argv[2].split(',')
	#command = sys.argv[3]
	#command = "echo \"true\" > \".net_status\""
	#command = "echo \"false\" > \".net_status\""
	#suffix=`date +%d-%m-%Y`
	#command = "(crontab -l 2>/dev/null; echo \"50 1 * * * sudo reboot\") | crontab -"
	today = datetime.date.today()
	suffix = str(today.day) + '-' + str(today.month) + '-' + str(today.year)
	curr_id = int(time.time())
	sync_time = curr_id + 120 
	
	# [MEET] 
	#command = "./videoconf-tester.sh -a meet -m nfk-ttfy-bzi --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 500 --id " + str(curr_id)
	#command = "./videoconf-tester.sh -a meet -m nfk-ttfy-bzi --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 500 --id " + str(curr_id) + " --video"
	#command = "./videoconf-tester.sh -a meet -m nfk-ttfy-bzi --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 500 --id " + str(curr_id) + " --video" + " --sync " + str(sync_time)
	
	# [ZOOM] 
	#command = "./videoconf-tester.sh -a zoom -m 4170438763 -p 6m2jmA --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 400 --id " + str(curr_id) + " --sync " + str(sync_time)  
	#command = "./videoconf-tester.sh -a zoom -m 4170438763 -p 6m2jmA --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 400 --id " + str(curr_id)
	command = "./videoconf-tester.sh -a zoom -m 6893560343 -p m06Yb9 --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 400 --id " + str(curr_id)
	#command = "./videoconf-tester.sh -a zoom -m 4170438763 -p 6m2jmA --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 400 --id " + str(curr_id) + " --view --video"

	#[WEBEX]
	#command = "./videoconf-tester.sh -a webex -m 1828625842 --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 500 --id " + str(curr_id) + " --video"
	#command = "./videoconf-tester.sh -a webex -m 1828625842 --dur 30 --suffix " + suffix + " --pcap --iface wlan0 --clear --big 500 --id " + str(curr_id) + " --sync " + str(sync_time)
	info = insert_pi_command(command_id, uid_list, time.time(), command, str(300), "false")
	print(info)
else: 
	print("USAGE: " + sys.argv[0] + " opt [ssh/update/restart] [uid-list]")
