## NOTE: web-app to manage NYU mobile testbed
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
## TESTING
## curl -H "Content-Type: application/json" --data '{"data":"testing data"}' https://mobile.batterylab.dev:8082/status

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

# connect to databse 
def connect_to_database(): 
	print("connecting to database")
	conn = psycopg2.connect(database = 'mobile_testbed', user = 'nyu', password = 'pa0l1n0', 
		host = '127.0.0.1', port = '5432', sslmode = 'require')
	cur = conn.cursor()  
	return True, conn, cur


# run a generic query on the database
def run_query(query):
	info = None
	msg = ''

	# connecting to db 
	connected = False 
	conn = None
	try:
		connected, conn, cur = connect_to_database()

	# manage exception 
	except psycopg2.DatabaseError as e:
		if conn:
			conn.rollback()
		msg = 'Issue connecting to database. Error %s' % e    

	# add installed_addons to database 
	if connected: 
		try:
			cur.execute(query)
			info = cur.fetchall()
			if len(info) > 0: 
				msg = 'OK'
			else: 
				info = None
				msg = 'WARNING -- no entry found'

		# handle exception 
		except Exception as e:
			msg = 'Issue querying the database. Error %s' % e    

		# always close connection
		finally:
			if conn:
				conn.close()

	# all good 
	return info, msg 


# insert status update from a device in the database
def insert_data(tester_id, location, timestamp, data_json):
	# local parameters 
	msg = '' 

	# connecting to db 
	connected = False 
	try:
		connected, conn, cur = connect_to_database()

	# manage exception 
	except psycopg2.DatabaseError as  e:
		if conn:
			conn.rollback()
		msg = 'Issue connecting to database. Error %s' % e    

	# add installed_addons to database 
	if connected: 
		try:
			insert_sql = "insert into status_update(tester_id, location, timestamp, data) values(%s, %s, %s, %s::jsonb);"
			insert_data = (tester_id, location, timestamp, data_json)			
			cur.execute(insert_sql, insert_data)
			msg = "exp_summary:all good" 	

			# make database changes persistent 
			conn.commit()

		# handle exception 
		except Exception as e:
			msg += 'Issue inserting into database. Error %s' % e    

		# always close connection
		finally:
			if conn:
				conn.close()

	# all done 
	return msg 


# simple function to read json from a POST message 
def read_json(req): 
	cl = req.headers['Content-Length']
	rawbody = req.body.read(int(cl))
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
supportedIDs = ['1234']          # list of client IDs supported 

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

    # POST/REPORT-MEASUREMENTS 
    cherrypy.tree.mount(StringGeneratorWebService(), '/status', conf)
 
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
		
		# see if there is an action 
		elif 'action' in cherrypy.url():
			if 'id' not in cherrypy.request.params: 
				cherrypy.response.status = 400
				print("Malformed URL")
				return "Error: Malformed URL" 
			user_id = cherrypy.request.params['id']
			if user_id not in supportedIDs: 
				cherrypy.response.status = 400
				print("User %s is not supported" %(user_id))
				return "Error: User is not supported"
			
			# TODO --  look for a potential action to be performed
			
			# all good 
			print("All good")
			cherrypy.response.status = 200
			return "All good"

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
		if 'status' in cherrypy.url():
			data_json = read_json(cherrypy.request)
			#print(data_json)
			tester_id = data_json['uid']
			location = None
			timestamp = data_json['timestamp']			
			msg = insert_data(tester_id, location, timestamp, data_json)
			print(msg)
			#info, msg  = run_query("select * from status_update")
			#print(info, msg)
			
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
	# start a thread which handle client-server communication 
	THREADS.append(Thread(target = web_app()))
	THREADS[-1].start()
	
	# listen to Ctrl+C
	signal.signal(signal.SIGINT, signal_handler)
