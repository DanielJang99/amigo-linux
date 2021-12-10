#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello (matteo.varvello@nokia.com)
## Date: 11/1/2021
import time 
import json 
import sys
import psycopg2
from psycopg2 import pool

# connect to databse 
def connect_to_database(): 
	print("connecting to database")
	conn = psycopg2.connect(database = 'mobile_testbed', user = 'nyu', password = 'pa0l1n0', 
		host = '127.0.0.1', port = '5432', sslmode = 'require')
	cur = conn.cursor()  
	return True, conn, cur



# connect to databse (with a pool)
def connect_to_database_pool(): 
	postgreSQL_pool = None
	try:
		print("connecting to database with a pool")
		postgreSQL_pool = psycopg2.pool.SimpleConnectionPool(1, 20, user="nyu",
					password="pa0l1n0",
					host="127.0.0.1",
					port="5432",
					database="mobile_testbed")
		if (postgreSQL_pool):
			print("Connection pool created successfully")
			status = True
			postgreSQL_pool.getconn()
		else: 
			print("Something is wrong")
			status = False 
	except (Exception, psycopg2.DatabaseError) as error:
		print("Error while connecting to PostgreSQL", error)
		status = False 
	
	# all good 
	return status, postgreSQL_pool

# insert status update from a device in the database
def insert_data_pool(tester_id, post_type, timestamp, data_json, postgreSQL_pool):
	# local parameters 
	msg = '' 

	# Use getconn() to Get Connection from connection pool
	ps_connection = postgreSQL_pool.getconn()

	if (ps_connection):
		try:
			print("successfully received connection from connection pool ")
			ps_cursor = ps_connection.cursor()
			insert_sql = "insert into status_update(tester_id, type, timestamp, data) values(%s, %s, %s, %s::jsonb);"
			data = (tester_id, post_type, timestamp, json.dumps(data_json))
			ps_cursor.execute(insert_sql, data)
			conn.commit()   # make database changes persistent 	
			ps_cursor.close()

			# Use this method to release the connection object and send back to connection pool
			postgreSQL_pool.putconn(ps_connection)
			print("Put away a PostgreSQL connection")
			msg = "status_update:all good" 				

		# handle exception 
		except Exception as e:
			msg += 'Issue inserting into database. Error %s' % e    

		# always close connection
		finally:
			if ps_cursor:
				ps_cursor.close()
			if ps_connection:
				postgreSQL_pool.putconn(ps_connection)
	else:
		msg = "Issue getting a connection from the pool"    

	# all done 
	return msg

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
def insert_pi_command(command_id, tester_id_list, timestamp, action, duration, isBackground):
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
			insert_sql = "insert into commands(command_id, tester_id_list, command, duration, background, timestamp, status) values(%s, %s, %s, %s, %s, %s, %s);"	
			data = (command_id, tester_id_list, action, duration, isBackground, timestamp, "{active}")
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


# insert status update from a device in the database
def insert_data(tester_id, post_type, timestamp, data_json):
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
			insert_sql = "insert into status_update(tester_id, type, timestamp, data) values(%s, %s, %s, %s::jsonb);"
			data = (tester_id, post_type, timestamp, json.dumps(data_json))
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
