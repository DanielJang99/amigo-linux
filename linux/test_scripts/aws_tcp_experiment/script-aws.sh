#!/bin/bash
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

# helper to stop previous stop pending
function stop_previous(){  
    # stop any remote sender running  
    command="cd ${SRC_DIR} && ./stop-gen.sh sender $1"
    remote_command "${command}"
    
    # stop local receiver
    ./stop-gen.sh receiver $1
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
    stop_previous "partial" 
    exit -1 
}

# helper to execute a remote command
function remote_command(){
    command=$1
    background="false"
    if [ $# -eq 2 ]
    then
        background="true"
    fi
    #myprint "[remote_command] ${command} => ${background}"
    if [ ${useSSH} == "true" ]
    then
        if [ ${background} == "true" ]
        then
            ssh -i ${key} -p ${ssh_sender_port} ${AWS_USER}@${ssh_sender} "${command}" &
        else 
            ssh -i ${key} -p ${ssh_sender_port} ${AWS_USER}@${ssh_sender} "${command}"
        fi 
    else 
        myprint "Currently support for no SSH is under development!"
        exit -1 
    fi
}


# fixed parameters
ssh_sender="ec2-54-205-30-146.compute-1.amazonaws.com"     # sender address (used for ssh)
ssh_sender_port="22"                                       # sender port (used for ssh)
sender_iface="enX0"                                        # sender main interface (for tcpdump)
AWS_USER="ec2-user"                                        # sender user (used for ssh)
key="~/.ssh/nvirginia_irtt_server_key.pem"                 # local ssh key 
TCP_CC="cubic"                                             # default congestion control algo at sender
exp_id=`date +%s`                                          # experiment identifier 
RUN_ID=0                                                   # run identifier 
useTCPDUMP="false"                                         # flag to control if to use tcpdump or not
use_hystart=0                                              # flag to control if to use hystart or not
rate=10                                                    # available rate in Mbps (to estimate file size)
SRC_DIR="/home/ec2-user/leo-sender"                        # default running folder at the sender
target_duration=15                                         # default experiment duration 
warmup_time=5                                              # sender warmup time 
useSSH="true"                                              # flag to control SSH usage or not 
SENDER_PORT=12345                                          # default sender port 

# Function to display usage information
usage() {
    echo "Usage: $0 [-c|--cc TCP_CC] [-r|--rate RATE] [-e|--exp-id EXP_ID] [--ID RUN_ID] [--dur TARGET_DURATION] [--tcpdump] [--noSSH]"  1>&2
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
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
    shift
done

# update timeout based on duration (give one extra min)
let "TIMEOUT = target_duration + 60"

# local folder organization
res_folder="results/${exp_id}/${TCP_CC}/${RUN_ID}"
if [ -d ${res_folder} ]
then 
    rm -rf ${res_folder}
fi 
mkdir -p ${res_folder}

# remote folder organization 
command="mkdir -p ${SRC_DIR}/${res_folder}"
remote_command "${command}"

# check for hystart in requested congestion control 
SHORT_TCP_CC=${TCP_CC}
if [[ "$TCP_CC" == *"hystart"* ]]
then 
    use_hystart=1
    SHORT_TCP_CC=${TCP_CC//_hystart/}
    myprint "Hystart was requested (only cubic allowed)"
fi 

# cleanup any pending process
myprint "Stopping any pending process, and cleaning previous logs (with full option)!"
stop_previous "full"

# verify TCP settings at the sender (no saving metrics + use window scaling)
myprint "Make sure TCP metrics are not being saved across runs..."
command="sudo sysctl -w net.ipv4.tcp_no_metrics_save=1 && sudo sysctl -w net.ipv4.tcp_adv_win_scale=1" 
remote_command "${command}"

# update TCP stack at the sender
myprint "Updating congestion control to ${TCP_CC} at the sender"
command="sudo sysctl -w net.ipv4.tcp_congestion_control=${SHORT_TCP_CC}"
remote_command "${command}"

command="sudo modprobe tcp_${SHORT_TCP_CC}"
remote_command "${command}"

command="sysctl net.ipv4.tcp_congestion_control"
remote_command "${command}"

myprint "Updating hystart (1) or lackof (0)"
command="echo ${use_hystart} | sudo tee /sys/module/tcp_cubic/parameters/hystart"
remote_command "${command}"

## FQ? This is needed for BBRv2 for which I need more recent machines
#sudo sysctl -w net.core.default_qdisc=fq
#net.core.default_qdisc = pfifo_fast

# make sure we are using the right file and it exits 
file_size=$(echo "${rate} * ${target_duration} / 8" | bc)
file_name="samplefile_${file_size}.bin"
myprint "Generating file to be served. Size: ${file_size} MB"
command="cd ${SRC_DIR} && ./create-file.sh ${file_name} ${file_size}"
remote_command "${command}"

# start the sender
sender_log="${SRC_DIR}/sender-log"
pcap_file="${SRC_DIR}"/full.pcap
if [ ${useTCPDUMP} == "true" ]
then
    command="cd ${SRC_DIR} && (sudo tcpdump -i ${sender_iface} -v -w ${pcap_file} &) && python3 -u sender.py ${file_name} > ${sender_log} 2>&1 &"
else 
    command="cd ${SRC_DIR} && python3 -u sender.py ${file_name} > ${sender_log} 2>&1 &"
fi 
myprint "Starting sender (requires a client connection to start sending). Command: ${command}"
remote_command "${command}" "true"

# allow server warmup or things to calm down...
myprint "Sleep ${warmup_time} to warmup AWS sender!"
sleep ${warmup_time}

# start the "receiver"
receiver_log="${res_folder}/receiver-log"
myprint "Receiver started (on the phone)"
(python3 -u receiver.py > ${receiver_log} 2>&1 &)

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
        break
    fi 
done

# cleanup any pending process across machines, just in case
stop_previous "partial"

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

# logging
myprint "FileSize:${file_size} Duration:${file_duration} Goodput:${goodput}"

# clean file which was served (since can get big at high transmission rates)
command="cd ${SRC_DIR} && rm -v ${file_name}"
remote_command "${command}"

# parse socket stats at the sender to save space 
receiver_IP=$(curl -s ifconfig.me)
out_log="${res_folder}/client-socket-stats-${receiver_IP}"
command="cd ${SRC_DIR} && ./compress-ss.sh ss-log ${receiver_IP} ${out_log} ${SENDER_PORT}"
myprint "Remote log compression: ${command}"
remote_command "${command}"

# do some TCP plotting at the server
myprint "Plotting cwnd..."      
command="cd ${SRC_DIR} && python3 cwnd-plot-simple.py ${out_log} ${file_duration} ${goodput} ${file_size}"
remote_command "${command}"

# collect plot (for debugging)
collect_plot="true"
if [ ${collect_plot} == "true" ]
then 
    scp -i ${key} -P ${ssh_sender_port} ${AWS_USER}@${ssh_sender}:${SRC_DIR}/${res_folder}/*.pdf ${res_folder}
fi 

# All done
myprint "All done!"