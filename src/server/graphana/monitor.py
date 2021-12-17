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
def insert_stats_pool(current_time, perc_cpu, perc_mem, traffic_rx, num_proc, created, num_users):
	# local parameters 
	msg = '' 

	# Use getconn() to Get Connection from connection pool
	ps_connection = postgreSQL_pool.getconn()

	if (ps_connection):
		try:
			print("successfully received connection from connection pool ")
			ps_cursor = ps_connection.cursor()
			insert_sql = "insert into stats(timestamp, cpu_perc, mem_perc, traffic_rx, num_proc, when_created, num_users) values(%s, %s, %s, %s, %s, %s, %s);"
			print(insert_sql)
			data = (current_time, perc_cpu, perc_mem, traffic_rx, num_proc, created, num_users)
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
			msg = 'OK'
			info = ps_cursor.fetchall()
			ps_cursor.close()
			msg = 'OK'
			postgreSQL_pool.putconn(ps_connection)
		# handle exception 
		except Exception as e:
			msg = 'Exception: %s' % e    
	
	# all good 
	return info, msg 


# parameters 
processName = "web-app.py" # make sure our process is running 
frequency = 300            # check stats each 5 minutes

# main goes here 
if __name__ == '__main__':

	# create connection pool to the database 
	connected, postgreSQL_pool = connect_to_database_pool()
	if not connected: 
		print("Issue creating the connection pool")
		
	# iterate on data 
	while True:
		current_time = time.time()
		perc_cpu = psutil.cpu_percent(30)

		# gives an object with many fields
		#psutil.virtual_memory()
		# you can convert that object to a dictionary 
		#dict(psutil.virtual_memory()._asdict())
		# you can have the percentage of used RAM
		#psutil.virtual_memory().percent

		# you can calculate percentage of available memory
		#perc_mem = psutil.virtual_memory().available * 100 / psutil.virtual_memory().total

		#Iterate over the all the running process
		num_proc = 0 
		create_time = 0 
		for proc in psutil.process_iter():
			try:
				if processName in proc.cmdline():
					num_proc += 1 
					#print(proc)
					create_time = proc.create_time()
					#print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(create_time)))
			except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
				pass
		
		# restart process if needed 
		## TODO 

		# find how many users are currently on
		query = "select count(distinct tester_id)::int as num_users from status_update where type = 'status' and to_timestamp(timestamp) > now() - interval '15 minutes';"
		info, msg  = run_query(query)
		num_users = int(info[0][0])

		# logging
		created = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(create_time))		
		print("Time:%d\tCPU:%f\tNUM_PROC:%d\tCREATED:%s" %(current_time, perc_cpu, num_proc, created))
		perc_mem = -1 
		traffic_rx = 0 

		# add to database for plotting
		msg = insert_stats_pool(current_time, perc_cpu, perc_mem, traffic_rx, num_proc, created, num_users)	
		print(msg)

		time.sleep(frequency)
