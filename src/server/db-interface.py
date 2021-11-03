#!/usr/bin/env python
import sys
import time
import json
import db_manager
from db_manager import run_query, insert_data

# handle ctrl-c 
def signal_handler(signal, frame):
    print('You pressed Ctrl+C!')
    sys.exit(0)

# run a query 
query = sys.argv[1]
print("QUERY:", query)
info, msg  = run_query(query)
print("INFO:", info)
print("MSG", msg)

# insert data in database
#info = insert_data(test_id, tester_id, location, timestamp, power_json, sense_json)
#print(info)

