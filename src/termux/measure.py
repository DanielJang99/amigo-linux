import sys
import re
import os

if len(sys.argv) != 3:
    print("Usage: %s <dir> <local-ip-address>" % (sys.argv[0]))
    exit()

probe_dir = sys.argv[1]
probe_cmd = "mtr -r %s > %s/%s &"
probe_tbl = dict()
probe_tbl[sys.argv[2]] = 1
delay_file = probe_dir + '/delay.txt'
big_packet_size = 400   # for Zoom

sys.stdout = open(delay_file, 'w')

if not os.path.exists(probe_dir):
    os.mkdir(probe_dir)

init_ts = 0
prv_ts = -10
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
        #print(ts, src_ip, src_port, dst_ip, dst_port, size)
        if dst_ip not in probe_tbl:
            #print ("Probing %s" % dst_ip)
            os.system(probe_cmd % (dst_ip, probe_dir, dst_ip))
            probe_tbl[dst_ip] = 1
        
        if (size > big_packet_size) and (cur_ts > 10):
            if (cur_ts - prv_ts) > 2:
                print ("%f\t%s:%s\t%s:%s\t%d" % (cur_ts, src_ip, src_port, dst_ip, dst_port, size))


sys.stdout.close()
