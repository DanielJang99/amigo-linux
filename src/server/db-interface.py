#!/usr/bin/env python
import sys
import time
import json
import db_manager
from db_manager import run_query, insert_data
# USAGE examples: 
# python db-interface.py "delete from status_update;"
# python db-interface.py "select * from status_update"

# run a query 
query = sys.argv[1]
print("QUERY:", query)
info, msg  = run_query(query)
print("INFO:", info)
print("MSG", msg)

# insert data in database
#info = insert_data(test_id, tester_id, location, timestamp, power_json, sense_json)
#print(info)
