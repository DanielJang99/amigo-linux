#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
import time 
import json 
import sys
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
			msg = 'OK'
			if 'select' in query or 'SELECT' in query:
				info = cur.fetchall()
				if len(info) > 0: 
					msg = 'OK'
				else: 
					info = None
					msg = 'WARNING -- no entry found'					
        
		# handle exception 
		except Exception as e:
			msg = 'Exception: %s' % e    
	
		# always close connection and make things persistent
		finally:
			if conn:
				conn.commit()
				conn.close()

	# all good 
	return info, msg 

# insert command for pi
def insert_command(command_id, tester_id, timestamp, action):
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
			insert_sql = "insert into action_update(command_id, tester_id, timestamp, status, action) values(%s, %s, %s, %s, %s);"	
			data = (command_id, tester_id, timestamp, "active", action)
			cur.execute(insert_sql, data)
			msg = "action_update:all good" 	
			
			# make database changes persistent 
			conn.commit()

		# handle exception 
		except Exception as e:
			msg += 'Exception: %s' % e    

		# always close connection
		finally:
			if conn:
				conn.close()

	# all done 
	return msg

# insert command for pi
def insert_pi_command(command_id, tester_id, timestamp, action, duration, isBackground):
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
			insert_sql = "insert into commands(command_id, tester_id, command, duration, background, timestamp, status) values(%s, %s, %s, %s, %s, %s, %s);"	
			data = (command_id, tester_id, action, duration, isBackground, timestamp, "active")
			cur.execute(insert_sql, data)
			msg = "action_update:all good" 	
			
			# make database changes persistent 
			conn.commit()

		# handle exception 
		except Exception as e:
			msg += 'Exception: %s' % e    

		# always close connection
		finally:
			if conn:
				conn.close()

	# all done 
	return msg #!/usr/bin/env python


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
			data = (tester_id, location, timestamp, json.dumps(data_json))
			cur.execute(insert_sql, data)
			msg = "status_update:all good" 	
			
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
