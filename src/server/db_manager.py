#!/usr/bin/python
## Notes: Common functions for database 
## Author: Matteo Varvello 
## Date: 07/27/2020
import time 
import json 
import sys
import psycopg2

# connect to safekodi databse 
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


# insert data from an experiment in the database 
def insert_data(test_id, tester_id, location, timestamp, power_json = None, sense_json = None):
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
			insert_sql = "insert into exp_summary(test_id, tester_id, location, timestamp) values(%s, %s, %s, %s);"
			insert_data = (test_id, tester_id, location, timestamp)
			cur.execute(insert_sql, insert_data)
			msg = "exp_summary:all good" 	

			# add in other table if needed
			if power_json is not None and sense_json is not None:
				insert_sql = "insert into experiments(test_id, tester_id, location, timestamp, power_data, sense_data) values(%s, %s, %s, %s, %s::jsonb, %s::jsonb);"
				insert_data += (power_json, sense_json)
				cur.execute(insert_sql, insert_data)
				msg += "experiments:all good" 	
			else: 
				print("WARNING -- Missing power data or sensing data")

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
