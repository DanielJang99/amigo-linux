#!/data/data/com.termux/files/usr/bin/env bash

#set -x      # Enable debugging
## NOTE:     script to automate Starlink on plane TCP experiments (assume runs on the phone)
## AUTHOR:   Matteo Varvello <matteo.varvello@nokia.com>
## DATE:     03/17/2025

# helper to clean a file if it exists
function clean_file(){
    if [ -f $1 ]
    then 
        rm -v $1
    fi 
}


# Helper for better logging
function myprint(){
    timestamp=`date +%s`
    val=$1
    if [ $# -eq  0 ]
    then
        return 
    fi
    echo -e "\033[32m[$0][$timestamp]\t${val}\033[0m"      
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    myprint "Trapped CTRL-C. Stop and cleanup"
    timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/awsend
    ./stop-gen.sh receiver "partial" 
    exit -1 
}


generate_post_data(){
  cat <<EOF
    {
    "server_loc":"${server_loc}",
    "timestamp":"${exp_id}",
    "uid":"${uid}",
    "physical_id":"${physical_id}",
    "experiment_id":"${exp_id}",
    "run_id":"${RUN_ID}",
    "useTcpDump":"${useTCPDUMP}",
    "useHystart":"${use_hystart}",
    "warmup_time":"${warmup_time}",    
    "useSsh":"${useSSH}",
    "rate":"${rate}", 
    "duration":"${target_duration}",
    "cc":"${TCP_CC}",
    "sender_port":"${SENDER_PORT}", 
    "filename":"${file_name}"
    }
EOF
}


# fixed parameters
sender_iface="ens5"                                        # sender main interface (for tcpdump)
AWS_USER="ec2-user"                                        # sender user (used for ssh)
key="~/.ssh/nvirginia_irtt_server_key.pem"                 # local ssh key 
TCP_CC="cubic"                                             # default congestion control algo at sender
exp_id=`date +%s`                                          # experiment identifier 
RUN_ID=0                                                   # run identifier 
useTCPDUMP="false"                                         # flag to control if to use tcpdump or not
use_hystart=0                                              # flag to control if to use hystart or not
rate=70                                                    # available rate in Mbps (to estimate file size)
target_duration=15                                         # default experiment duration 
warmup_time=10                                              # sender warmup time 
useSSH="true"                                              # flag to control SSH usage or not 
SENDER_PORT=12345                                          # default sender port 
SERVER_PORT=8082
server_loc="us-east-1"                                     # default server location

# coin toss to select which port to use 
FLIP=$(($(($RANDOM%10))%2))
if [ $FLIP -eq 1 ]
then
	SERVER_PORT=8082
else 
	SERVER_PORT=8083
fi

# Function to display usage information
usage() {
    echo "Usage: $0 [-c|--cc TCP_CC] [-r|--rate RATE] [-e|--exp-id EXP_ID] [--ID RUN_ID] [--dur TARGET_DURATION] [--tcpdump] [--noSSH] [-s|--server-loc LOCATION]"  1>&2
    echo "Valid server locations: us-east-1, eu-west-2, me-central-1, eu-central-1" 1>&2
    exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ID)
            RUN_ID=$2
            shift
            ;;
        -c|--cc)
            TCP_CC=$2
            shift
            ;;
        --dur)
            target_duration=$2
            shift
            ;;
        -r|--rate)
            rate=$2
            shift
            ;;
        -e|--exp-id)
            exp_id=$2
            shift
            ;;
        -h|--help)
            usage
            ;;
        --tcpdump)
            useTCPDUMP="true"
            ;;
        --noSSH)
            noSSH="false"
            myprint "Currently support for no SSH is under development!"
            exit -1 
            ;;
        -s|--server-loc)
            case "$2" in
                us-east-1|eu-west-2|me-central-1|eu-central-1)
                    server_loc=$2
                    ;;
                *)
                    echo "Error: Invalid server location. Valid options are: us-east-1, eu-west-2, me-central-1, eu-central-1" >&2
                    usage
                    ;;
            esac
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
    shift
done

file_size=$(echo "${rate} * ${target_duration} / 8" | bc)
file_name="samplefile_${file_size}.bin"

# retrieve unique ID for this device 
if [ -f ".uid" ]
then
	uid=`cat ".uid" | awk '{print $2}'`
	physical_id=`cat ".uid" | awk '{print $1}'`
else
	uid=`su -c service call iphonesubinfo 1 s16 com.android.shell | cut -c 52-66 | tr -d '.[:space:]'`
	uid_list_path="/data/data/com.termux/files/home/mobile-testbed/src/termux/uid-list.txt"
	if [ -f "$uid_list_path" ]
	then
		physical_id=`cat "$uid_list_path" | grep $uid | head -n 1 | awk '{print $1}'`
	fi
fi
myprint "IMEI: $uid PhysicalID: $physical_id"

# # update timeout based on duration (give one extra min)
let "TIMEOUT = target_duration + 60"

# local folder organization
res_folder="results/${exp_id}/${TCP_CC}/${RUN_ID}"
if [ -d ${res_folder} ]
then 
    rm -rf ${res_folder}
fi 
mkdir -p ${res_folder}

echo "$(generate_post_data)" 		
timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/awsstart

# allow server warmup or things to calm down...
myprint "Sleep ${warmup_time} to warmup AWS sender!"
sleep ${warmup_time}

# start the "receiver"
receiver_log="${res_folder}/receiver-log"
myprint "Receiver started (on the phone)"
(python3 -u receiver.py -s ${server_loc} > ${receiver_log} 2>&1 &)

# wait for experiment to be over
sleep 2
t_start=`date +%s`
was_timeout="false"
grep_val="receiver.py" 
myprint "Start monitoring for experiment to be over. Grep_val:${grep_val}"
while true 
do 
    ans=`ps aux | grep "${grep_val}" | grep -v "grep" | wc -l`
    myprint "Active clients: ${ans}"
    if [ ${ans} -gt 0 ]
    then 
        t_end=`date +%s`
        let "t_passed = t_end - t_start"
        if [ ${t_passed} -gt ${TIMEOUT} ]
        then 
            myprint "ERROR! TIMEOUT"
            was_timeout="true"
            break
        fi 
        sleep 5 
    else
        myprint "Receive Done" 
        break
    fi 
done

# stop local receiver
# ./stop-gen.sh receiver "partial"
for pid in `ps aux | grep "python" | grep "receiver" | grep -v "grep" | awk '{print $2}'`
do
        #sudo kill -9 ${pid}
        sudo kill ${pid}  # Use SIGTERM instead of SIGKILL
done

# stop remote sender 
timeout 15 curl -s -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://mobile.batterylab.dev:$SERVER_PORT/awsend


# receiver 
if [ ${was_timeout} == "false" ] 
then
    cat ${receiver_log} | grep "successfully" > ".success"
    N=`wc -l ".success"  | awk '{print $1}'`
    file_duration=0
    goodput=0     
    if [ $N -eq 1 ]
    then 
        #file_duration=`cat ".success"  | cut -f 2 -d "-" | cut -f 2 -d ":"`
        file_duration=`cat ".success"  | cut -f 3 -d "-" | cut -f 2 -d ":" | cut -f 1 -d " " | sed s/"s"//g`
        #goodput=`cat ".success"  | cut -f 3 -d "-" | cut -f 2 -d ":"`
        goodput=`cat ".success"  | cut -f 4 -d "-" | cut -f 2 -d ":" | cut -f 1 -d " "`
        #file_size=`cat ".success"  | cut -f 4 -d "-" | cut -f 2 -d ":"`
        file_size=`cat ".success" | cut -f 2 -d "-" | cut -f 2 -d ":" | cut -f 1 -d " "`
        rm "received_file.txt"
    else
        myprint "Something is wrong, it seems file was not delivered correctly. Check file <<received_file.txt>>"
    fi 
else 
    cat ${receiver_log} | grep "interrupted" > ".fail"
    file_duration=`cat ".fail"  | cut -f 2 -d ":"`
    file_size=`stat --format="%s" received_file.txt`
    goodput=$(echo "scale=2; (${file_size}*8) / ${file_duration}" | bc)
    rm "received_file.txt"
fi 

myprint "FileSize:${file_size} Duration:${file_duration} Goodput:${goodput}"
