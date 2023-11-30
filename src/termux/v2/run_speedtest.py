#!/usr/bin/env python
import subprocess
import sys
import json
from datetime import date 

DAILY_MOBILE_DATA_LIMIT = 300000000 # limit = 300mb 

class SpeedtestOptions:
    BOTH = "speedtest-cli --json"
    DOWNLOAD = "speedtest-cli --json --no-upload"
    UPLOAD = "speedtest-cli --json --no-download"

def run_test(cmd, outputFile):
    run = subprocess.run(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if run.returncode != 0:
        exit(1) 
    out = run.stdout.decode('utf-8')
    with open(outputFile, "w") as f:
        f.write(out)
    out_json = json.loads(out)
    bytesSent=out_json["bytes_sent"]
    bytesReceived=out_json["bytes_received"]
    return bytesSent+bytesReceived

def write_logs(logfile, msg):
    with open(logfile, "w") as f:
        f.write(msg)

def main(network_type, outputfile, logfile=None, last_test_day=None, bytes_used=None):
    if network_type == "WIFI":
        run_test(SpeedtestOptions.BOTH, outputfile)
    else:
        today = date.today().strftime("%d-%m-%Y")
        if not last_test_day or not bytes_used:
            test_bytes = run_test(SpeedtestOptions.BOTH, outputfile)
            write_logs(logfile, f"{today} {test_bytes}")
            return 
        # run both download & upload test if this is the first test of the day
        if (last_test_day != today):
            test_bytes = run_test(SpeedtestOptions.BOTH, outputfile)
            write_logs(logfile, f"{today} {test_bytes}")
            return 
        
        bytes_used = int(bytes_used)
        # skip if we have already used more than 300mb for speedtest today
        if bytes_used > DAILY_MOBILE_DATA_LIMIT:
            print("DATA_EXCEEDED")
            return
        
        test_bytes = run_test(SpeedtestOptions.BOTH, outputfile)
        write_logs(logfile, f"{today} {test_bytes+bytes_used}")
        
        
        # # run download if our previous test today was upload, and vice versa. Exit if it exceeds daily data limit 
        # if last_test_type == "up":
        #     test_bytes = run_test(SpeedtestOptions.DOWNLOAD, outputfile)
        #     if test_bytes + bytes_used < DAILY_MOBILE_DATA_LIMIT:
        #         test_bytes += run_test(SpeedtestOptions.UPLOAD, outputfile)
        #         write_logs(f"{today} {test_bytes+bytes_used} up {network_type}")
        #     else:
        #         write_logs(f"{today} {test_bytes+bytes_used} down {network_type}")




if '__main__' == __name__:    
    if len(sys.argv) == 3:
        main(sys.argv[1], sys.argv[2])
    elif len(sys.argv) == 4:
        main(sys.argv[1], sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 6:
        main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    else:
        print("Invalid Number of Arguments")
        exit(1)