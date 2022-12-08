## NOTE: web-app to manage NYU mobile testbed
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
## POST API
## curl -H "Content-Type: application/json" --data '{"data":"testing data"}' https://mobile.batterylab.dev:8082/status
## GET API 
## curl https://mobile.batterylab.dev:8082/action?id=1234
## POST API (via APP)
## curl -H "Content-Type: application/json" --data '{"uid":"c95ad2777d56", "timestamp":"1635973511", "command_id":"1234", "command":"recharge"}' https://mobile.batterylab.dev:8082/appstatus

#!/usr/bin/python
#import random
import string
import json
import cherrypy
import os
from os.path import exists
from threading import Thread
import threading
import signal
import sys
import time 
import argparse
import simplejson
import subprocess
import psycopg2
import db_manager
from db_manager import run_query, insert_data, insert_command, connect_to_database_pool, insert_data_pool, insert_code
import random 
import ipaddress

# function to check current VM status -- need its own thread to run
def check_vm_status():
	print("[INFO] Started thread to check VM status") 
	global vm_app, vm_status, session_users, timeQuickFix, VideoRec, status, timeStopped
	freq = 60        # check status every minute
	time.sleep(freq) # give it a sleep since before started thread we gave it a go 
	while run:
		# kick out very old users and stop videoconf if still running
		curr_time = int(time.time())
		to_remove = []
		for key, value in session_users.items(): 
			t_passed = (curr_time - value)
			if t_passed > 300:
			#if t_passed > MAX_DURATION:
				print("[thread_vm_check] Marked user %s from session_users as inactive since no data for the past 5 minutes" %(key))
				#print("[thread_vm_check] Marked user %s from session_users to remove since time expired (%d)" %(key, t_passed))
				to_remove.append(key)
		for key in to_remove: 
			del session_users[key]
			if key in RTT:
				del RTT[key]

		# check if we should stop the videoconference (and VMs) or not
		if len(session_users) == 0 and status == "started":
			status = "stopped"
			VideoRec = {}
			videoconf_id = "none"   # resetting videoconf id since not needed anyway
			print("[thread_vm_check] Stopping videoconferencing host since no user left!") 
			command = "./manager-videoconf-addon.sh --opt stop"
			print("[thread_vm_check] Executing command: ", command) 
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			timeQuickFix = int(time.time())
			timeStopped = timeQuickFix
			for loc in vm_status.keys():
				vm_status[loc] = 1	
	
	  	# stop the VM if needed 
		timeSinceStopped = int(time.time()) - timeStopped
		if status == "stopped" and timeSinceStopped > 600: 
			status = "killed" 
			command = "./manager-videoconf-addon.sh --opt kill"
			print("[thread_vm_check] 10 minutes passed from videoconf stop. Killing the VMs: ", command) 
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
				
		# rate control!
		time.sleep(freq)

	# thread is done
	print("Stopped thread to check VM status")

# function to check current VM status -- need its own thread to run
# NOTE: not using due to race condition. We instead rely on sequence of events 
def check_vm_status_old():
	print("[INFO] Started thread to check VM status") 
	global vm_app, vm_status, session_users, timeQuickFix, VideoRec, status, timeStopped

	freq = 60        # check status every minute
	time.sleep(freq) # give it a sleep since before started thread we gave it a go 
	while run:
		# avoid checking status for the next two minutes after a VM change (aka trust start/stop/kill/launch work) 
		timeSinceQuicFix = int(time.time()) - timeQuickFix
		if timeSinceQuicFix < 120:
			timeToSleep = 120 - timeSinceQuicFix
			print("[thread_vm_check] Recent command detected. Delaying check for:", timeToSleep)
			time.sleep(timeToSleep)
		else: 
			print("[thread_vm_check] No recent command detected. timeSinceQuicFix: ", timeSinceQuicFix)
		
		# cleaning and reloading from file so that we can be more dynamic
		vm_app_new = {}
		with open('app-vm-mapping.txt') as file:
			for line in file:
				fields = line.rstrip().split('\t')
				app = fields[0]
				location = fields[1]
				vm_app_new[app] = location
	
		# iterate on app/vms mapping 
		for app, location in vm_app_new.items():
			#print("[check_vm_status] Checking app %s for location %s" %(app, location))
			if location != "inaws" and location != "home":
				if 'use' in location:
					group_location = 'use'
				else:
					group_location = location
				command = "az vm get-instance-view --name " + location + " --resource-group loc-" + group_location + " --query instanceView.statuses[1] | grep \"VM running\""
				p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
				temp = p.communicate()
				vm_status[location] = p.returncode
			else: 
				vm_status[location] = 0 	

			# in case the VM is up, further check that videoconf is running
			if vm_status[location] == 0: 
				ssh_user = azure_user
				ssh_port = 22 
				if location == "inaws":
					ssh_user = "ubuntu" 
				elif location == "home": 
					ssh_user = "varvello"
					ssh_port = 6789
				azure_server = azure[location]
				command = "ps aux | grep 'firefox\|chrome' | grep -v grep | grep " + app + " | wc -l"
				if app == 'zoom':
					command = "ps aux | grep zoom | grep tee | grep -v grep | wc -l"
				p = subprocess.Popen("ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p {port} -i {key} {user}@{host} {cmd}".format(port = ssh_port, key = azure_key, user = ssh_user, host = azure_server, cmd = command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
				out, err = p.communicate()
				if p.returncode != 0:
					print("[thread_vm_check] ERROR -- SSH to %s failed" %(location))
					vm_status[location] = 1	
					continue
				num_proc = int(out.strip())
				if num_proc == 1: 
					vm_status[location] = 0
					status = "started"      # just reinforce that something is running
					vm_status[location] = p.returncode
				elif num_proc == 0: 
					vm_status[location] = 1
				else:
					vm_status[location] = 1
					print("[thread_vm_check] ERORR! Something is wrong. %d processes found for app %s at location %s" %(num_proc, app, location))
			print("[thread_vm_check] Location:", location, "APP:", app, "Status: ", vm_status[location])
		
		# updating data structures (should really need a lock here)
		vm_app.clear()
		vm_app = vm_app_new.copy()
	
		# kick out very old users and stop videoconf if still running
		curr_time = int(time.time())
		to_remove = []
		for key, value in session_users.items(): 
			t_passed = (curr_time - value)
			if t_passed > MAX_DURATION:
				print("[thread_vm_check] Marked user %s from session_users to remove since time expired (%d)" %(key, t_passed))
				to_remove.append(key)
		for key in to_remove: 
			del session_users[key]
			if key in RTT:
				del RTT[key]

		# check if we should stop the videoconference (and VMs) or not
		if len(session_users) == 0 and status == "started":
			status = "stopped"
			videoconf_id = "none"
			VideoRec = {}
			print("[thread_vm_check] Stopping videoconferencing host since no user left!") 
			command = "./manager-videoconf-addon.sh --opt stop"
			print("[thread_vm_check] Executing command: ", command) 
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			timeQuickFix = int(time.time())
			timeStopped = timeQuickFix
			for loc in vm_status.keys():
				vm_status[loc] = 1	
	
	  	# stop the VM if needed 
		timeSinceStopped = int(time.time()) - timeStopped
		if status == "stopped" and timeSinceStopped > 300: 
			status = "killed" 
			print("[thread_vm_check] 5 minutes passed from videoconf stop. Killing the VMs: ", command) 
			command = "./manager-videoconf-addon.sh --opt kill"
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	
		# rate control!
		time.sleep(freq)

	# thread is done
	print("Stopped thread to check VM status")

# run a generic query on the database (pool)
def run_query_pool(query, postgreSQL_pool):
	info = None
	msg = ''

	# Use getconn() to Get Connection from connection pool
	ps_connection = postgreSQL_pool.getconn()
	if (ps_connection):
		try:
			ps_cursor = ps_connection.cursor()
			ps_cursor.execute(query)
			if 'select' in query or 'SELECT' in query:
				info = ps_cursor.fetchall()
			else: 
				ps_connection.commit()
			msg = 'OK'
		# handle exception 
		except Exception as e:
			msg = 'Exception: %s' % e    
		# finally close things 
		finally:
			ps_cursor.close()
			postgreSQL_pool.putconn(ps_connection)	
	# all good 
	return info, msg 

# simple function to read json from a POST message 
def read_json(req): 
	cl = req.headers['Content-Length']
	rawbody = req.body.read(int(cl))
	body = simplejson.loads(rawbody)	
	return body 

# helper to derive a videoconf URL
def compute_url(app, vm_location):
	# videoconf parameters
	meeting_info = {'zoom-ch':'3190389183', 'zoom-use':'2598883628', 'zoom-in':'9548135127', 'zoom-home':'4189460601', 'zoom-use2':'7761594917', 'zoom-use3':'6893560343',
					'webex-ch':'26ba4694280b70efc4ea898ad03cc45d', 'webex-in':'', 'webex-use':'5f9302fff62ad24450132962511c732c', 'webex-use2':'4bf6de9eb24eb6a149a0b822379e5ddb', 'webex-use3':'4f9315fd47b030c6c128fab0e2c71ac6', 'webex-home':'xxxx',
					'meet-ch':'qmw-vqvj-idq', 'meet-in':'fef-ymqm-fup', 'meet-use':'yzv-zmyj-mmv', 'meet-use2':'kwq-bufb-nxz', 'meet-use3':'wdq-vezv-xft', 'meet-inaws':'rnp-thzb-jqx', 'meet-home':'gto-cgqb-dqn'}
	webex_info =   {'ch':'meet180', 'use':'meet9', 'use2':'meet9', 'use3':'meet10'}
	#https://us05web.zoom.us/wc/join/85702336962?pwd=eUpUOUJHc0VreEVBN3U3dStwVUt0QT09
	#https://meet10.webex.com/wbxmjs/joinservice/sites/meet10/meeting/download/4f9315fd47b030c6c128fab0e2c71ac6
	zoom_password = {'ch':'d28yamU2cGJmaDgrUk9vREJpRktHQT09', 'in':'Q0RNeUJHZHpieVdlUU1mODFmZ0FhUT09', 'use':'OXM0RW5NV3U3dDlCZDhxTEJRRkZCQT09', 'use2':'eExudGtXZXZZTnhsV09MQlAvbHQxUT09', 'use3':'L09WUGdpTUlkLytTazRhTXZHdkc1UT09', 'home':'WmVFb1VrU2RPMHd3QzEwRUxHWnZXZz09'}
	meeting_id = meeting_info[app + '-' + vm_location]
	if app == 'zoom':
		# NOTE: zoom password is "abc" for each VM
		return "https://us05web.zoom.us/wc/join/" + meeting_id + "?pwd=" + zoom_password[vm_location]
	elif app == 'webex':
		return "https://" + webex_info[vm_location] + ".webex.com/wbxmjs/joinservice/sites/ + webex_info[vm_location] + '/meeting/download/" + meeting_id + "?launchApp=true" 	
	elif app == 'meet':
		return "https://meet.google.com/" + meeting_id
			
# global parameters
port    = 8084                    # default listening port 
THREADS = []                      # list of threads 
ACL     = True                    # control whether application ACL rules should be used 
allowedips      = {               # ACL rules 
    '127.0.0.1':'-1',                     
    '98.109.67.104':'-1',                     
    '173.70.180.54':'-1',                     
}
session_id = ""
session_data = {}
supportedIDs = ['c95ad2777d56']    # list of client IDs supported 
id_control  = False                # flag for client ID control 
postgreSQL_pool = None             # pool of connection to DB
letters = string.ascii_lowercase   # collection of lowercase letter used to compute unique identifier
run = True                         # flag to check whether to start thread to check on VMs
vm_status = {}                     # dictionary of current VM status
vm_app = {}                        # mapping VM and APP 
azure_user = "azureuser"           # default user for azure 
azure_key    = "/root/.ssh/id_rsa" # ssh key for azure
#azure = {"ch":"20.203.184.236", "in":"40.80.84.104", "use":"20.120.91.176", "use2":"20.231.212.81", "use3":"20.231.108.191", "inaws":"43.204.112.148", "home":"96.242.92.32"}  # current VM info 
azure = {"ch":"20.203.184.236", "in":"40.80.84.104", "use":"20.232.23.111", "use2":"23.101.138.166", "use3":"20.228.215.26", "inaws":"43.204.112.148", "home":"96.242.92.32"}  # current VM info 
#use2: 23.101.138.166  (videoconf ID: hohnjusw101@gmail.com)
#use3: 20.228.215.26 (videoconf ID: hohnjusc101@gmail.com)
azure_group = {"ch":"", "in":"", "use":"use", "use2":"use", "use3":"use"} # azure group information per location
videoconf_id = "none"              # unique identifier of current videoconference 
last_user = "none"                 # keep track of last user -- useful for controlled experiments
timeQuickFix = 0                   # keep track if we manually changes VM status or not 
isVideoRec = True                  # enable videorecording or not 
DEFAULT_CONF_DURATION = 180        # max videoconf duration for addon users 
RTT = {}                           # keep track of RTT (physical + clock sync) per user
session_users = {}                 # keep track of user session durations
MAX_DURATION = 900                 # users have 15 minutes to complete a job 
status = ""                        # keep track if VMs/videoconferences status
VideoRec = {}                      # keep track of for which app we are videorecording already 
timeStopped = int(time.time())     # keep track of when videoconf were stopped 
addonid = "hgplgkibjnndogdgejjhkjjnhalfiebb"
isStarlink  = {}                   # dictionary of flags to control starlink experiments per user 
isProlific = True                  # flag to control if we are running a prolific experiment, aka max one user at a time
prevApp = "none"                   # keep track of previous videoconferencing app that was run
videoRefresh = True                # flag to control if to restart the video when recording get enabled 
STARLINK_IPV4 = []                 # list of starlink IPv4 prefixes 

# helper to check if contacting IP is from starlink
def check_for_starlink(IP, RULES):
	for rule in RULES: 
		if ipaddress.ip_address(IP) in ipaddress.ip_network(rule):
			return True
	return False 
 
# function to run a bash command
def run_bash(bashCommand, verbose = True):
	process = subprocess.Popen(bashCommand.split(), stdout = subprocess.PIPE, stdin =subprocess.PIPE, shell = False)
	output, error = process.communicate()
	
	#if verbose: 
	print("Command: " + bashCommand + " Output: " + str(output) + " Error: " + str(error))

	# all good (add a check?)
	return str(output.decode('utf-8'))

# pre-flight request => http://www.w3.org/TR/cors/#cross-origin-request-with-preflight-0    
def cors():
  # logging 
  if cherrypy.request.method == 'OPTIONS':
    cherrypy.response.headers['Access-Control-Allow-Methods'] = 'POST'
    cherrypy.response.headers['Access-Control-Allow-Headers'] = 'content-type'
    cherrypy.response.headers['Access-Control-Allow-Origin']  = '*'
    # tell CherryPy no avoid normal handler
    return True
  else:
    cherrypy.response.headers['Access-Control-Allow-Origin'] = '*'

# thread to control client-server communication
def web_app():
    # configuration 
    conf = {
        '/': {
            'request.dispatch': cherrypy.dispatch.MethodDispatcher(),
            'tools.sessions.on': True,
            'tools.response_headers.on': True,
        }
    }

    cherrypy.tools.cors = cherrypy._cptools.HandlerTool(cors)
    server_config={
        'server.socket_host': '0.0.0.0',
        'server.socket_port': port, 
        'server.ssl_module':'builtin',
        #'server.ssl_module': 'pyopenssl',
        'server.ssl_certificate':'certificate.pem',
        'server.thread_pool': 50,
    }
    cherrypy.config.update(server_config)

    # GET 
    cherrypy.tree.mount(StringGeneratorWebService(), '/addACLRule', conf)
    cherrypy.tree.mount(StringGeneratorWebService(), '/removeACLRule', conf)
    cherrypy.tree.mount(StringGeneratorWebService(), '/action', conf)         # for now query each rand(30) seconds
    cherrypy.tree.mount(StringGeneratorWebService(), '/commandDone', conf)    # allow marking a command as done
    cherrypy.tree.mount(StringGeneratorWebService(), '/code', conf)           # get e new code for payment of check for a code validity
    cherrypy.tree.mount(StringGeneratorWebService(), '/confIDS', conf)        # get info on current conference IDs to be used 
    cherrypy.tree.mount(StringGeneratorWebService(), '/manage', conf)         # start/stop VMs/experiment
    cherrypy.tree.mount(StringGeneratorWebService(), '/videorec', conf)       # start/stop videorecording if needed
    cherrypy.tree.mount(StringGeneratorWebService(), '/RTT', conf)            # allow to measure RTT and potential clock issues
    cherrypy.tree.mount(StringGeneratorWebService(), '/info', conf)           # return <last_user:videoconf_id> -- useful for controlled experiments

    # POST/REPORT-MEASUREMENTS 
    cherrypy.tree.mount(StringGeneratorWebService(), '/addonstatus', conf)    # report status of experiment (CPU, UA, etc.) 
    cherrypy.tree.mount(StringGeneratorWebService(), '/addontest', conf)      # report screenshots from an experiment
    cherrypy.tree.mount(StringGeneratorWebService(), '/addonid', conf)        # return last addon identifier

    # start cherrypy engine 
    cherrypy.engine.start()
    cherrypy.engine.block()

# catch ctrl-c
def signal_handler(signal, frame):

	# logging 
	print('You pressed Ctrl+C!')

	# stop VM status monitoring thread 
	print("stopping VM monitoring thread")
	run = False 
	THREADS[1].do_run = False
	THREADS[1].join()
	
	# kill main web app thread 
	print("stopping main thread")
	THREADS[0].do_run = False
	THREADS[0].join()

	# kill cherrypy
	print("stopping cherrypy webapp")
	cherrypy.engine.exit()

	# exiting from main process
	sys.exit(0)


@cherrypy.expose
class StringGeneratorWebService(object):

	@cherrypy.tools.accept(media='text/plain')
	def GET(self, var=None, **params):
		global videoconf_id, timeQuickFix, session_users, VideoRec, status, timeStopped, last_user, prevApp, isStarlink

		# switch between different URLs 
		src_ip = cherrypy.request.headers['Remote-Addr']
		
		# ignore Google testing IPs? 
		if src_ip.startswith("66.102") or src_ip.startswith("66.249") or src_ip.startswith("74.125.215"):
			print("[WARNING] Detected Google IP (they test new uploaded addon). Ignoring")
			return 
		if src_ip == '41.0.136.241' or src_ip == '105.244.157.150' or src_ip == '41.0.133.144':
			print("[WARNING] Detected %s - IP from SouthAfrica which keeps connecting to use. Ignoring" %(src_ip))
			return 

		if 'code' in cherrypy.url():
			if 'code' in cherrypy.request.params: 
				# logging 
				print("received a request to verify mturk  code:", src_ip, cherrypy.request.params['code'])
				
				# query the db for a code for this user -- which needs to match what reported
				query = "select code from crowdsourcing where tester_ip = '" + src_ip + "' and to_timestamp(timestamp) > now() - interval '10 mins' order by timestamp desc"
				info, msg  = run_query_pool(query, postgreSQL_pool)							
				print(info, msg)				

				# prepare response to send back 				
				ans = {}				
				ans['msg']="ERROR"				
				if info is None or len(info) == 0:
					cherrypy.response.status = 202
					print(src_ip, ans)
					return "myCallBackMethod(" + json.dumps(ans) + ")"
				local_code = info[0][0] 				
				cherrypy.response.status = 200				
				if local_code == cherrypy.request.params['code']:
					ans['msg'] = "ok"
				print(src_ip, ans)
				return "myCallBackMethod(" + json.dumps(ans) + ")"
			else: 
				# logging 
				user_id = cherrypy.request.params['uid']
				print("received a request to generate a mturk code from %s" %(user_id))
				
				# compute unique code to be returned (unless already available in db)
				query = "select code from crowdsourcing where tester_ip = '" + src_ip + "' and to_timestamp(timestamp) > now() - interval '10 mins' order by timestamp desc"
				info, msg  = run_query_pool(query, postgreSQL_pool)							
				if info is not None and len(info) > 0:
					print("Found code available in db")
					code_to_return = info[0][0] 				
				else: 
					print("Generating a new code")
					code_to_return = ''.join(random.choice(letters) for i in range(12))

				##############
				print("Temporarily forcing code to 32739F8A for PROLIFIC") 
				code_to_return = '32739F8A'
				#############

				# decide if we can stop the videoconference or not (aka if user is last or not) 
				if user_id in session_users: 
					del session_users[user_id]
					if user_id in RTT:
						del RTT[user_id]
					print("Removed user %s from session_users. Current size: %d" %(user_id, len(session_users)))
					if len(session_users) == 0: 
						status = "stopped" 
						VideoRec = {}
						print("Stopping videoconferencing host since this was the last user in this session!") 
						command = "./manager-videoconf-addon.sh --opt stop"
						print("Executing command: ", command) 
						p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
						timeQuickFix = int(time.time())
						timeStopped = timeQuickFix
						for loc in vm_status.keys():
							vm_status[loc] = 1
				else:
					print("WARNING. User requested code but never joined a conference")
				ans = {}
				ans['code'] = code_to_return
				
				# insert code in the database 
				insert_code(src_ip, time.time(), code_to_return, postgreSQL_pool)

				# keep track of info of users who finished 
				line_to_dump = user_id
				query = "select data->>'user_location', data->>'user-agent', data->>'videoconf_id', data->>'ip' from status_update  where tester_id = '" + user_id + "' and type = 'addonstatus' and data->>'app' = 'fast' and data->>'message' = 'unload';"
				info, msg  = run_query_pool(query, postgreSQL_pool)
				if len(info) == 0: 
					print("No speedtest data found for message unload. Relaxing the query using backup approach: updateapp")
					query = "select data->>'user_location', data->>'user-agent', data->>'videoconf_id', data->>'ip' from status_update  where tester_id = '" + user_id + "' and type = 'addonstatus' and data->>'app' = 'fast' and data->>'message' = 'updateapp';"
					info, msg  = run_query_pool(query, postgreSQL_pool)
				if len(info) != 0: 
					for i in range(0,4):
						line_to_dump += ':' + str(info[0][i])
				else:
					line_to_dump += '::' + str(videoconf_id)
				line_to_dump += '\n'
				with open("wild-controlled-summary", 'a') as f:
					f.write(line_to_dump)	

				# send out the response 
				print(src_ip, ans)
				cherrypy.response.status = 200				
				return "myCallBackMethod(" + json.dumps(ans) + ")"
		elif 'RTT' in cherrypy.url():
			curr_time = int(time.time_ns()/1000000)
			send_ts = float(cherrypy.request.params['ts'])
			user_id = cherrypy.request.params['uid']
			time_shift = curr_time - send_ts
			if user_id not in RTT and user_id != "1234":
				print("[INFO] A new user (%s) joined the conference" %(user_id)) 
				RTT[user_id] = []
				session_users[user_id] = int(time.time())
				last_user = user_id 

				# check for starlink users
				isStarlink[user_id] = check_for_starlink(src_ip, STARLINK_IPV4)
				print("Is starlink?", isStarlink[user_id])

				# start the videoconference hosts unless a user is already there
				needToStart = True 
				for loc in vm_status.keys():
					if vm_status[loc] == 0:
						needToStart = False 
						break 
				status = "started" # wether already started or not, this is the right status
				if needToStart: 
					print("[INFO] Detected that we should start the videoconferencing hosts - status:", status, "NumUsers:", len(session_users), "RecordingStatus:", VideoRec)
					command = "./manager-videoconf-addon.sh --opt start"
					videoconf_id = int(time.time()) 
					command += " --id " + str(videoconf_id)
					print("Executing command: ", command) 
					p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

					# update local status to keep track things were started 
					timeQuickFix = int(time.time())
					for loc in vm_status.keys():
						vm_status[loc] = 0
					
					# keep track of which host configuration was used for this experiment 
					key_exp = 'zoom:'
					if 'zoom' in vm_app: 
						key_exp += vm_app['zoom'] 
					key_exp += ';meet:'
					if 'meet' in vm_app:
						key_exp += vm_app['meet'] 
					key_exp += ';webex:'
					if 'webex' in vm_app:
						key_exp += vm_app['webex']
					update_query = "UPDATE videoconf_addon_status SET videoconf_ids = videoconf_ids || '{\"" + str(videoconf_id) + "\"}' WHERE zoom_meet_webex_location = '" + key_exp + "';"
					print("Updating videoconf_addon_status:", update_query)
					info, msg  = run_query_pool(update_query, postgreSQL_pool)
					print("DB response:", msg)
				else: 
					print("[INFO] At least one videoconference (%s) is already running. Nothing to start" %(str(videoconf_id)))
			else:
				if user_id != "1234":
					session_users[user_id] = int(time.time()) # keep track of last time a user was seen 
			if user_id != "1234":
				RTT[user_id].append(time_shift)
			print("User", user_id, "SendTS", send_ts, "CurrTime", curr_time, "TimeShift:", time_shift)
			cherrypy.response.status = 200
			return ""
		elif 'videorec' in cherrypy.url():
			ans = {} 
			print("[INFO] Received a request to start videorecording -- isEnabled:", isVideoRec, "VideoRec:", VideoRec) 
		
			# make sure request is correct			
			if 'app' not in cherrypy.request.params:
				print("APP field missing")
				ans['msg'] = "ERROR. Missing app field" 
				return json.dumps(ans)
			app = cherrypy.request.params['app']
			loc = vm_app[app]
			azure_server = azure[loc]
			if isVideoRec and app not in VideoRec:
				ans['msg'] = "OK"
				VideoRec[app] = 1 
				if loc != "home":
					#command = "/home/azureuser/recordscreen.sh " + app + " " + str(videoconf_id) + " " + str(DEFAULT_CONF_DURATION) + " >.rec 2>&1 &"
					if videoRefresh: 
						command = "/home/azureuser/recordscreen.sh " + app + " " + str(videoconf_id) + " refresh >.rec 2>&1 &"
					else: 
						command = "/home/azureuser/recordscreen.sh " + app + " " + str(videoconf_id) + " >.rec 2>&1 &"
				else: 
					command = "/home/varvello/videconf-experimenting/cloudvm/recordscreen.sh " + app + " " + str(videoconf_id) + " >.rec 2>&1 &"
				ext_timeout = DEFAULT_CONF_DURATION + 20 
				ssh_user = azure_user
				ssh_port = 22 
				if loc == "inaws":
					ssh_user = "ubuntu" 
				elif loc == "home": 
					ssh_user = "varvello"
					ssh_port = 6789
				print("[INFO] Enabling video recording. App:%s Location:%s IP:%s Command:%s" %(app, loc, azure_server, command))
				p = subprocess.Popen("timeout {ext_timeout} ssh -t -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p {port} -i {key} {user}@{host} {cmd}".format(ext_timeout = ext_timeout, port = ssh_port, key = azure_key, user = ssh_user, host = azure_server, cmd = command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
				out, err = p.communicate()
				if p.returncode != 0:
					print("ERROR -- SSH to %s failed" %(azure_server))
					ans['msg'] = "ERROR"
			else:
				print("[INFO] Videorecording for this app was already started") 
				ans['msg'] = "NO-NEED"
			
			# in Prolific mode (one user at a time), ok to stop the "previous" conference (need to keep track) 
			if isProlific:
				if prevApp != "none":
					prevLoc = vm_app[prevApp]
					command = "./manager-videoconf-addon.sh --app " + prevApp + " --loc " + prevLoc + " --opt stop"
					print("Stopping videoconf for previous app. Command: ", command) 
					p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			################## testing 

			prevApp = app 
			print("[videorecording]", src_ip, ans)
			cherrypy.response.status = 200
			return json.dumps(ans)
		elif 'confIDS' in cherrypy.url():
			ans = {'meet': None, 'webex': None, 'zoom': None, 'starlink': None}
			
			 # keep track of last time a user was seen 
			user_id = cherrypy.request.params['uid']
			if user_id in session_users:
				session_users[user_id] = int(time.time())  
			
			# add starlink if needed 
			if user_id not in isStarlink:
				isStarlink[user_id] = check_for_starlink(src_ip, STARLINK_IPV4)
			if isStarlink[user_id]:
				ans['starlink'] = "http://dishy.starlink.com/statistics"
			
			# discover VM-app mapping
			ans['videoconf_id'] = videoconf_id
			for app, location in vm_app.items():
				if location not in vm_status: 
					continue
				if vm_status[location] == 0:		
					ans[app] = compute_url(app,  location)
			print("[GET => confIDS] App/VM Status: ", vm_status) 

			# send out response
			print(src_ip, ans)
			cherrypy.response.status = 200
			return json.dumps(ans)
		elif 'manage' in cherrypy.url():
			ans = {}
			
			# ACL control -- only allowed IPs can manage the videoconf sessions
			if ACL and src_ip not in allowedips:
				cherrypy.response.status = 403
				print("Requesting ip address (%s) is not allowed" %(src_ip))
				ans['msg'] = "ERROR. Forbidden. " + src_ip + " is not allowed" 
				return json.dumps(ans)
			
			# make sure API is used correctly 
			if 'command' not in cherrypy.request.params: 
				ans['msg'] = "ERROR. Missing parameter command" + " APP/VM mapping:" + str(vm_app)
				cherrypy.response.status = 403
				return json.dumps(ans)
			elif cherrypy.request.params['command'] not in ['start', 'stop', 'launch', 'kill']:
				ans['msg'] = "ERROR. Command not supported [start,stop,launch,kill]" + " APP/VM mapping:" + str(vm_app)
				cherrypy.response.status = 403
				return json.dumps(ans)
			rx_command = cherrypy.request.params['command']

			# prepare command to be executed 
			command = "./manager-videoconf-addon.sh --opt " + rx_command
			if 'app' in cherrypy.request.params:
				req_app = cherrypy.request.params['app']
				if req_app not in vm_app:
					ans['msg'] = "ERROR. App: " + req_app + " not in app-vm-mapping.txt -- " + str(vm_app)
					cherrypy.response.status = 403
					return json.dumps(ans)	
				command += " --app "  + req_app + " --loc " + vm_app[req_app]
			if 'confID' in cherrypy.request.params:
				videoconf_id = cherrypy.request.params['confID']
				print("Videoconf sessions id (passed in the GET):", videoconf_id) 
				command += " --id " + str(videoconf_id)
			elif rx_command == 'start': 
				videoconf_id = int(time.time())     # create a unique identifier for videoconference since user did not pass one
				print("Videoconf sessions id (generated by script):", videoconf_id) 
				command += " --id " + str(videoconf_id)
				
			# execute command 
			print("Executing command: ", command) 
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			
			# quickly updating VM status to improve on the 60 sec sleep (inconsistencies can still happen but should be rare)
			if rx_command == 'start': 
				timeQuickFix = int(time.time())
				print("Quickly updating app/vm mapping info")
				if 'app' in cherrypy.request.params:
					vm_status[vm_app[req_app]] = 0
				else: 
					#for loc in azure.keys(): 
					for loc in vm_status.keys():
						vm_status[loc] = 0
			if rx_command == 'stop' or rx_command == 'kill': 
				timeQuickFix = int(time.time())
				print("Quickly updating app/vm mapping info")
				if 'app' in cherrypy.request.params:
					vm_status[vm_app[req_app]] = 1
				else: 
					#for loc in azure.keys(): 
					for loc in vm_status.keys():
						vm_status[loc] = 1

			# log current VM status
			print("App/VM status: ", vm_status)

			# prepare response 
			ans['msg'] = 'OK -- ' + str(vm_app)
			cherrypy.response.status = 200
			return json.dumps(ans)
		elif 'info' in cherrypy.url():
			cherrypy.response.status = 200
			browser  = cherrypy.request.params['browser']
			machine  = cherrypy.request.params['machine']
			curr_app = cherrypy.request.params['app']
			line = last_user + ',' + str(videoconf_id) + ',' + machine + ',' + browser + ',' + curr_app + '\n'
			with open("controlled-exp-summary", 'a') as f:
				f.write(line)
			return last_user + ':' + str(videoconf_id)

	# handle POST requests 
	def POST(self, name="test"):
	
		# parameters 
		ret_code = 202	   # default return code 
		result = []        # result to be returned when needed 
		ans = ''           # placeholder for response 

		# extract incoming IP address 
		src_ip = cherrypy.request.headers['Remote-Addr']

		# status update reporting 
		url = cherrypy.url()
		if 'addonstatus' in url or 'addontest' in url:
			data_json = read_json(cherrypy.request)
			data_json['ip'] = src_ip
			user_id = data_json['uid']
			if user_id in session_users:
				session_users[user_id] = int(time.time())   # keep track of last time a user was seen 
			if 'addontest' in url and user_id in RTT: 
				data_json['serverRTT'] = RTT[user_id]
			if 'status' in cherrypy.url():
				post_type = "addonstatus"
				if 'videoconf_id' in data_json:
					data_json['videoconf_id'] = int(data_json['videoconf_id'])
			elif 'addontest' in cherrypy.url():
				post_type = "addontest"
			timestamp = data_json['timestamp']			
			msg = insert_data_pool(user_id, post_type, timestamp, data_json, postgreSQL_pool)	
		
			# respond all good 
			cherrypy.response.headers['Content-Type'] = 'application/json'
			cherrypy.response.headers['Access-Control-Allow-Origin']  = '*'
			cherrypy.response.status = ret_code
			if ans == '':
				ans = 'OK\n'

			# all good, send response back 
			return ans.encode('utf8')
		elif 'addonid' in cherrypy.url():
			ans = {}
			ans = addonid + '\n'
			cherrypy.response.headers['Content-Type'] = 'application/json'
			cherrypy.response.headers['Access-Control-Allow-Origin']  = '*'
			cherrypy.response.status = ret_code
			print("[ADDONID] Returning:", ans) 
			return ans.encode('utf8')

	# preflight request 
	# see http://www.w3.org/TR/cors/#cross-origin-request-with-preflight-0	
	def OPTIONS(self, name="test"): 
		cherrypy.response.headers['Access-Control-Allow-Methods'] = 'POST'
		cherrypy.response.headers['Access-Control-Allow-Headers'] = 'content-type'
		cherrypy.response.headers['Access-Control-Allow-Origin']  = '*'

	def PUT(self, another_string):
		cherrypy.session['mystring'] = another_string

	def DELETE(self):
		cherrypy.session.pop('mystring', None)

# main function 
def main():
	# parameters
	global vm_app, vm_status, postgreSQL_pool, STARLINK_IPV4

	# create connection pool to the database 
	connected, postgreSQL_pool = connect_to_database_pool()
	if not connected: 
		print("Issue creating the connection pool")
		sys.exit(-1)

	# load starlink IPv4 prefixes 
	with open('starlink-ipv4.conf') as file: 
		for line in file: 
			if 'allow' not in line:
				continue
			fields = line.rstrip().split('allow')
			STARLINK_IPV4.append(fields[1].replace(';', '').lstrip())

	# make sure vm mapping exists and is ready 
	if not exists('app-vm-mapping.txt'):
		print("ERROR. File 'app-vm-mapping.txt' is missing. Thread cannot be started")
		sys.exit(-1) 
	with open('app-vm-mapping.txt') as file:
		for line in file:
			fields = line.rstrip().split('\t')
			app = fields[0]
			location = fields[1]
			vm_app[app] = location
	print("Checking VM and videocon status --", vm_app)
	for app, location in vm_app.items():
		if location != "inaws" and location != "home":
			#if 'use' in location:
			#	group_location = 'use'
			#else:
			#	group_location = location
			#command = "az vm get-instance-view --name " + location + " --resource-group loc-" + group_location + " --query instanceView.statuses[1] | grep \"VM running\""
			command = "az vm get-instance-view --name " + location + " --resource-group " + azure_group[location] + " --query instanceView.statuses[1] | grep \"VM running\""
			p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			temp = p.communicate()
			vm_status[location] = p.returncode
		else: 
			vm_status[location] = 0	

		# in case the VM is up, further check that videoconf is running
		if vm_status[location] == 0: 
			azure_server = azure[location]
			ssh_user = azure_user
			ssh_port = 22 
			if location == "inaws":
				ssh_user = "ubuntu" 
			elif location == "home": 
				ssh_user = "varvello"
				ssh_port = 6789
			command = "ps aux | grep 'firefox\|chrome' | grep -v grep | grep " + app + " | wc -l"
			if app == 'zoom':
				command = "ps aux | grep zoom | grep tee | grep -v grep | wc -l"
			p = subprocess.Popen("ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p {port} -i {key} {user}@{host} {cmd}".format(port = ssh_port, key = azure_key, user = ssh_user, host = azure_server, cmd = command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			out, err = p.communicate()
			num_proc = int(out.strip())
			if num_proc == 1: 
				vm_status[location] = 0
				print("VM %s is up and app %s was found" %(location, app))
			elif num_proc == 0: 
				vm_status[location] = 1
				print("VM %s is up but app %s was not found" %(location, app))
			else:
				vm_status[location] = 1
				print("ERORR! Something is wrong. %d processes found for app %s at location %s" %(num_proc, app, location))
		print("Location:", location, "Status: ", vm_status[location])
	
	# start a thread which handle client-server communication 
	THREADS.append(Thread(target = web_app))
	#THREADS[-1].daemon = True
	THREADS[-1].start()
	
	# start a thread to monitor VM status 
	THREADS.append(Thread(target = check_vm_status))
	#THREADS[-1].daemon = True
	THREADS[-1].start()
	
	# listen to Ctrl+C
	signal.signal(signal.SIGINT, signal_handler)

# main goes here 
if __name__ == '__main__':
	main()
