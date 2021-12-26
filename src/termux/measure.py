import sys
import re
import os

# check usage
if len(sys.argv) != 5:
    print("Usage: %s <dir> <id> <local-ip-address> <big-packet-size>" % (sys.argv[0]))
    exit()

# read input
probe_dir = sys.argv[1]
test_id   = sys.argv[2]
local_ip  = sys.argv[3]
big_packet_size = int(sys.argv[4])


probe_cmd = "mtr -r -n %s > %s/%s"
probe_tbl = dict()
probe_tbl[local_ip] = 1
delay_file = probe_dir + '/' + test_id + '-delay.txt'
sys.stdout = open(delay_file, 'w')
if not os.path.exists(probe_dir):
    os.mkdir(probe_dir)
init_ts = 0
prv_ts = 0
print("Started")
for line in sys.stdin:
    output = re.findall(r"([^ ]*) IP (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d+) > (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d+):.*, length (\d+)", line)
    if output:
        cur_ts = float(output[0][0])
        src_ip = output[0][1]
        src_port = output[0][2]
        dst_ip = output[0][3]
        dst_port = output[0][4]
        size = int(output[0][5])
        #print(cur_ts, src_ip, src_port, dst_ip, dst_port, size)
        if src_ip not in probe_tbl:        
            #print ("Probing %s" % src_ip)
            out_file = test_id + '-' + src_ip
            os.system(probe_cmd % (src_ip, probe_dir, out_file))
            probe_tbl[src_ip] = 1
        if prv_ts == 0:
            prv_ts = cur_ts
        if (size > big_packet_size) and (cur_ts > 10):
            if (cur_ts - prv_ts) > 2:
                print ("%f\t%s:%s\t%s:%s\t%d" % (cur_ts, src_ip, src_port, dst_ip, dst_port, size))
                prv_ts = cur_ts
sys.stdout.close()