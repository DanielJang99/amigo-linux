#!/data/data/com.termux/files/usr/bin/env bash

# generate data to be POSTed to my server
generate_post_data(){
  cat <<EOF
    {
    "today":"${suffix}",
    "timestamp":"${current_time}",
    "uid":"${uid}",
    "debug":"${debug}",
    "msg":"${msg}"
    }
EOF
}

# check packages 
pkg upgrade -y
pkg install -y termux-api tsu root-repo mtr python tcpdump tshark ffmpeg imagemagick
python -m pip install --upgrade pip
pip install speedtest-cli
pip install wheel
pip install pillow
./check-visual.sh 

# main code 
uid=`termux-telephony-deviceinfo | grep device_id | cut -f 2 -d ":" | sed s/"\""//g | sed s/","//g | sed 's/^ *//g'`
suffix=`date +%d-%m-%Y`
current_time=`date +%s`
msg="DONE"
echo "$(generate_post_data)" 
t_s=`date +%s`
timeout 30 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:8082/benchmarking
t_e=`date +%s`
let "t_p = t_e - t_s"
echo "CURL_DURATION: $t_p"