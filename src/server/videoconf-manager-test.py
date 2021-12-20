#!/usr/bin/env python
import psutil
import time 
import sys
import psycopg2
from psycopg2 import pool

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
		else: 
			print("Something is wrong")
			status = False 
	except (Exception, psycopg2.DatabaseError) as error:
		print("Error while connecting to PostgreSQL", error)
		status = False 
	
	# all good 
	return status, postgreSQL_pool

# run a generic query on the database
def run_query(query):
	info = None
	msg = ''

	# Use getconn() to Get Connection from connection pool
	ps_connection = postgreSQL_pool.getconn()
	if (ps_connection):
		try:
			print("successfully received connection from connection pool ")
			ps_cursor = ps_connection.cursor()
			ps_cursor.execute(query)
			info = ps_cursor.fetchall()
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


# parameters 
VIDEOCONF_SIZE = 4          # 1 host + 3 phones

# start the host 
# TODO 

# main goes here 
if __name__ == '__main__':

	# create connection pool to the database 
	connected, postgreSQL_pool = connect_to_database_pool()
	if not connected: 
		print("Issue creating the connection pool")
		

	# find devices currently available, along with networking info 
	query = "select distinct(tester_id) from status_update WHERE type = 'status' and  data->>'vrs_num' is not NULL and to_timestamp(timestamp) > now() - interval '1 hrs';"
	print(query)		
	info, msg  = run_query(query)
	print(info)
	sys.exit(-1) 

	# iterate on testers until three are found who match
	active_tester = [ ] 
	for tester_id in active_testers: 
		query = "select tester_id, data->>'wifi_ip', data->>'mobile_ip', data->>'battery_level', data->>'net_testing_proc' from status_update WHERE type = 'status' and  data->>'vrs_num' is not NULL and to_timestamp(timestamp) > now() - interval '15 min' and tester_id = '" + tester_id + "';"
		print(query)
		info, msg  = run_query(query)
		print(info)

		# geolocate IPs -- TODO 

		# if user match constraints, add to a list 


		# check if we have a list ready for testing
		candidate_testers = []		
		if len(candidate_testers) == VIDEOCONF_SIZE - 1: 
			print("start the conference")
			# wait for things to be done -- TODO 

			# add an entry to the db -- TODO
			# clean list 
			candidate_testers.clear()
