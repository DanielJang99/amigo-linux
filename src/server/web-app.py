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
from db_manager import run_query, insert_data, insert_command

# simple function to read json from a POST message 
def read_json(req): 
	cl = req.headers['Content-Length']
	rawbody = req.body.read(int(cl))
	#body = simplejson.load(rawbody)
	body = simplejson.loads(rawbody)	
	return body 

# global parameters
port    = 8082                    # default listening port 
THREADS = []                      # list of threads 
ACL     = False                   # control whether application ACL rules should be used 
allowedips      = {               # ACL rules 
    '127.0.0.1':'-1',                     
}
session_id = ""
session_data = {}
supportedIDs = ['c95ad2777d56']   # list of client IDs supported 
id_control  = False               # flag for client ID control 

# function to run a bash command
def run_bash(bashCommand, verbose = True):
	process = subprocess.Popen(bashCommand.split(), stdout = subprocess.PIPE, stdin =subprocess.PIPE, shell = False)
	output, error = process.communicate()
	
	#if verbose: 
	print("Command: " + bashCommand + " Output: " + str(output) + " Error: " + str(error))

	# all good (add a check?)
	return str(output.decode('utf-8'))

# pre-flight request 
# see http://www.w3.org/TR/cors/#cross-origin-request-with-preflight-0    
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
        'server.ssl_certificate':'certificate.pem',
    }
    cherrypy.config.update(server_config)

    # GET - ADD/REMOVE-ACL-RULE (localhost only)
    cherrypy.tree.mount(StringGeneratorWebService(), '/addACLRule', conf)
    cherrypy.tree.mount(StringGeneratorWebService(), '/removeACLRule', conf)
    cherrypy.tree.mount(StringGeneratorWebService(), '/action', conf)        # for now query each rand(30) seconds
    #cherrypy.tree.mount(StringGeneratorWebService(), '/myaction', conf)        # query when kenzo app is in foreground
    cherrypy.tree.mount(StringGeneratorWebService(), '/commandDone', conf)     # allow marking a command as done

    # POST/REPORT-MEASUREMENTS 
    cherrypy.tree.mount(StringGeneratorWebService(), '/status', conf)
    cherrypy.tree.mount(StringGeneratorWebService(), '/appstatus', conf)     # report charging state, wifi password, etc. 

    # start cherrypy engine 
    cherrypy.engine.start()
    cherrypy.engine.block()

# catch ctrl-c
def signal_handler(signal, frame):

	# logging 
	print('You pressed Ctrl+C!')

	# kill throughput thread 
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
		
		# log last IP that contacted the server
		src_ip = cherrypy.request.headers['Remote-Addr']
		
		# ACL control 
		if ACL: 
			if not src_ip in allowedips:
				cherrypy.response.status = 403
				print("Requesting ip address (%s) is not allowed" %(src_ip))
				return "Error: Forbidden" 

		# add ACL rule
		if 'addACLRule' in cherrypy.url():
			if 'ip' in cherrypy.request.params: 
				ip_to_add = cherrypy.request.params['ip']
				currentTime = int(time.time()) * 1000
				if ip_to_add in allowedips:
					print("Updating ip %s in allowedips" %(ip_to_add))
					msg = "Rule correctly updated"
				else:
					print("Adding new ip %s to allowedips" %(ip_to_add))
					msg = "Rule correctly added"

				# update or add the rule 
				allowedips[ip_to_add] = currentTime
				
				# respond all good 
				cherrypy.response.status = 200
				return msg

		# remove ACL rule 
		elif 'removeACLRule' in cherrypy.url():
			if 'ip' in cherrypy.request.params: 
				ip_to_remove = cherrypy.request.params['ip']
				if ip_to_remove in allowedips:
					del allowedips[ip_to_remove] 
					print("Remove ip %s from allowedips" %(ip_to_remove))
					
					# respond all good 
					cherrypy.response.status = 200
					return "Rule correctly removed"
				else:
					# respond nothing was done 
					cherrypy.response.status = 202
					return "Rule could not be removed since not existing"
		
		# see if there is a command
		elif 'action' in cherrypy.url():
			if 'id' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			user_id = cherrypy.request.params['id']
			if user_id not in supportedIDs and id_control:  
				cherrypy.response.status = 400
				print("User %s is not supported" %(user_id))
				return "Error: User is not supported"
			else: 
				print("User %s is supported" %(user_id))
			if 'prev_command' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			prev_command = cherrypy.request.params['prev_command']
			if 'termuxUser' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			termux_id  = cherrypy.request.params['termuxUser']
			
			# look for a potential action to be performed
			#query = "select * from commands where (tester_id = '" + user_id + "' or tester_id = '*') and command_id != '" + prev_command + "' and status != 'DONE';"
			query = "select * from commands where (tester_id = '" + user_id + "' or tester_id = '*') and command_id != '" + prev_command + "';"
			info, msg  = run_query(query)
			#print(info, msg)
			if info is None:
				cherrypy.response.status = 202
				print("No command matching the query found")
				return "No command matching the query found"
			#if len(info) > 1: 
			#	print("WARNING: too many actions active at the same time. Returning most recent one")
			max_timestamp = 0
			unique_id = termux_id + ';' + user_id
			for entry in info:
				print(entry)
				timestamp = entry[5]
				user_target = entry[1]
				status = entry[6]
				if user_target == "*" and user_id in status:
					continue
				if user_target == user_id and ('DONE' in status or unique_id in status):
					continue
				if timestamp > max_timestamp: 
					max_timestamp = timestamp 
					command = entry[2]
					comm_id = entry[0]
					duration = entry[3]
					isBackground = entry[4]
			
			# all good 
			if max_timestamp == 0:
				print("No command matching the query found")
				return "No command matching the query found"
			ans = command + ';' + str(max_timestamp) + ';' + comm_id + ';' + str(duration) + ';' + isBackground + '\n'
			print("All good. Returning: ", ans)
			cherrypy.response.status = 200
			return ans 

		# mark command as done
		elif 'commandDone' in cherrypy.url():
			if 'id' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			user_id = cherrypy.request.params['id']
			if user_id not in supportedIDs and id_control:  
				cherrypy.response.status = 400
				print("User %s is not supported" %(user_id))
				return "Error: User is not supported"
			else: 
				print("User %s is supported" %(user_id))
			if 'command_id' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			if 'termuxUser' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			command_id = cherrypy.request.params['command_id']
			termux_id  = cherrypy.request.params['termuxUser']
			comm_status = cherrypy.request.params['status'] #FIXME: potentially use this 

			# look for a potential action to be performed
			status = termux_id + ';' + user_id
			query = "update commands set status = array_append(status, '" + status + "') where command_id = '" + command_id + "';"
			print("==>", query)
			info, msg  = run_query(query)
			print(info, msg)
	
			# all good 
			print("Operation result:", msg)
			cherrypy.response.status = 200
			return msg

	# handle POST requests 
	def POST(self, name="test"):
	
		# parameters 
		ret_code = 202	   # default return code 
		result = []        # result to be returned when needed 
		ans = ''           # placeholder for response 

		# extract incoming IP address 
		src_ip = cherrypy.request.headers['Remote-Addr']

		# ACL control 
		if ACL: 
			if not src_ip in allowedips:
				cherrypy.response.status = 403
				print("Requesting ip address (%s) is not allowed" %(src_ip))
				return "Error: Forbidden" 

		# status update reporting 
		if 'status' in cherrypy.url() or 'appstatus' in cherrypy.url():
			data_json = read_json(cherrypy.request)
			print(data_json)
			#user_id = data_json['adb_id']
			user_id = data_json['uid']
			if user_id not in supportedIDs and id_control:  			
				cherrypy.response.status = 400
				print("User %s is not supported" %(user_id))
				return "Error: User is not supported"
			else: 
				print("User %s is supported" %(user_id))
			location = None
			timestamp = data_json['timestamp']			
			msg = ''
			if 'appstatus' in cherrypy.url():
				#command_id = data_json['command_id']
				command = data_json['command']				
				timestamp = data_json['timestamp']
				command_id = command + '-'  + str(timestamp)
				msg = insert_command(command_id, user_id, timestamp, command)
			else: 
				msg = insert_data(user_id, location, timestamp, data_json)
			print(msg)
			
		# respond all good 
		cherrypy.response.headers['Content-Type'] = 'application/json'
		cherrypy.response.headers['Access-Control-Allow-Origin']  = '*'
		cherrypy.response.status = ret_code
		if ans == '':
			ans = 'OK\n'

		# all good, send response back 
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

# main goes here 
if __name__ == '__main__':

	## TODO: query supported device ids to populate supportedIDs

	# start a thread which handle client-server communication 
	THREADS.append(Thread(target = web_app()))
	THREADS[-1].start()
	
	# listen to Ctrl+C
	signal.signal(signal.SIGINT, signal_handler)
