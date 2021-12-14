#!/usr/bin/env python
import psutil
import time 

processName = "web-app.py" # make sure our process is running 
frequency = 300            # check stats each 5 minutes (avoid heavy query to DB)

# iterate on data 
while True:
	current_time = time.time()
	perc_cpu = psutil.cpu_percent(1)

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

	# logging
	print("Time:%d\tCPU:%f\tNUM_PROC:%d\tCREATED:%s" %(current_time, perc_cpu, num_proc, time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(create_time))))

	# restart process if needed 
	## TODO 

	time.sleep(frequency)
