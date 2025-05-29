#!/bin/bash
## NOTE: Linux container network testing script 
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-05-29


# import util file
DEBUG=1
util_file=`pwd`"/utils.sh"
if [ -f $util_file ]
then
    source $util_file
else
    echo "Util file $util_file is missing"
    exit 1
fi

# Cleanup background processes
cleanup_processes() {
    for pid in $(ps aux | grep -E 'speed-test|web-test|mtr|cdn-test|youtube-test|latency-test' | grep -v grep | awk '{print $2}'); do
        kill -9 $pid 2>/dev/null
    done
    killall tcpdump 2>/dev/null
}


# Watch test timeout
watch_test_timeout() {
    local test_pid=$1
    local timeout_duration=${2:-$TEST_TIMEOUT}
    
    (sleep $timeout_duration && kill -9 $test_pid 2>/dev/null) & 
    local watcher=$!
    
    if wait $test_pid 2>/dev/null; then
        kill -9 $watcher 2>/dev/null
        wait $watcher 2>/dev/null
        myprint "Test completed successfully"
        return 0
    else
        myprint "Test process killed after running for $timeout_duration seconds"
        return 1
    fi
}

# Run experiment with connectivity check
run_experiment() {
    local test_command="$1"
    network_status=$(check_network_status)
    if [[ "$network_status" == *"true"* ]]; then
        myprint "Running test: $test_command"
        eval "$test_command" &
        local exp_pid=$!
        watch_test_timeout $exp_pid
    else
        myprint "Unable to run $test_command due to no internet connection: $network_status"
    fi
}

# DNS testing
run_dns_test() {
    myprint "Running DNS test"
    dns_res_folder="./results/dns-results/$suffix"
    mkdir -p "$dns_res_folder"
    curl -L https://test.nextdns.io > "${dns_res_folder}/$t_s.txt"
}


# MTR (traceroute) testing
run_mtr_test() {
    myprint "Running MTR test. Suffix: $suffix, Time: $t_s"
    ./test_scripts/mtr.sh $suffix $t_s
}

# Speed test
run_speed_test() {
    myprint "Running speed test. Suffix: $suffix, Time: $t_s"
    ./test_scripts/speed-test.sh --suffix $suffix --id $t_s
}

# CDN testing
run_cdn_test() {
    myprint "Running CDN test. Suffix: $suffix, Time: $t_s"
    ./test_scripts/cdn-test.sh $suffix $t_s
}


# Main execution
main() {
    # Parameters
    suffix=${1:-$(date +%d-%m-%Y)}
    t_s=${2:-$(date +%s)}
    iface=${3:-$(get_def_iface)}
    opt=${4:-"long"}

    myprint "Network testing parameters: Suffix: $suffix, Time: $t_s, Interface: $iface, Opt: $opt"
    
    # Configuration
    TEST_TIMEOUT=300
    
    # System information
    # container_id=$(cat /proc/self/cgroup 2>/dev/null | head -n1 | cut -d/ -f3 | cut -c1-12 || echo "unknown")
    
    t_start=$(date +%s)
    
    # Run DNS test
    run_experiment "run_dns_test"
    sleep 3
    
    # Run MTR test
    run_experiment "run_mtr_test"
    sleep 10
    
    # Run speed test
    run_experiment "run_speed_test"
    sleep 10
    
    # Run CDN test
    run_experiment "run_cdn_test"
    sleep 10


    # cleanup_processes
    
    # Final logging
    t_end=$(date +%s)
    duration=$((t_end - t_start))
    myprint "Linux network testing END. Duration: ${duration}s"
}

# Run main function with all arguments
main "$@"