#!/data/data/com.termux/files/usr/bin/bash

# folder organization
suffix=`date +%d-%m-%Y`
t_s=`date +%s`

# run a speedtest 
echo "[`date`] speedtest-cli..."
speedtest-cli --json > "mspeedtest-cli-logs/$suffix/speed-$t_s.json"

# run a speedtest in the browser (fast.com)
./speed-browse-test.sh $suffix $t_s

# run NYU stuff 
# TODO 

# run multiple MTR
./mtr.sh $suffix $t_s

# test multiple CDNs
./cdn-test.sh $suffix $t_s

# QUIC test? 

# test multiple webages 

# video testing
