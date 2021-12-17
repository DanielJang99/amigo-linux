#!/usr/bin/env python
import psutil
import time 
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

# insert stats for graphana plotting
def insert_emails(tester_id, physical_id, email, location, status):
	# local parameters 
	msg = '' 

	# Use getconn() to Get Connection from connection pool
	ps_connection = postgreSQL_pool.getconn()

	if (ps_connection):
		try:
			print("successfully received connection from connection pool ")
			ps_cursor = ps_connection.cursor()
			insert_sql = "insert into userinfo(tester_id, physical_id, email, location, status) values(%s, %s, %s, %s);"
			print(insert_sql)
			data = (tester_id, physical_id, email, location, status)
			ps_cursor.execute(insert_sql, data)
			ps_connection.commit()   # make database changes persistent 	
			ps_cursor.close()

			# Use this method to release the connection object and send back to connection pool
			postgreSQL_pool.putconn(ps_connection)
			msg = "status_update:all good" 				

		# handle exception 
		except Exception as e:
			msg += 'Issue inserting into database. Error %s' % e    
	else:
		msg = "Issue getting a connection from the pool"    

	# all done 
	return msg


# main goes here 
if __name__ == '__main__':

	# create connection pool to the database 
	connected, postgreSQL_pool = connect_to_database_pool()
	if not connected: 
		print("Issue creating the connection pool")
		
	# iterate on data 
	with open("device-info.txt") as file:
		for line in file:
			fields = line.split('\t')
			physical_id = fields[0]
			uid = fields[1]
			email = fields[2]
			location = fields[3]
			status = fields[4].strip()
			#print("insert_emails(" + physical_id + "," + uid + "," + email + "," + location + "," + status + ")")
			insert_emails(physical_id, uid, email, location, status)
			break
