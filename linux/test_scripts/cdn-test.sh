#!/bin/bash
## NOTE:  CDN tests adapted for Linux containers
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

# Helper function to test a download 
test_download(){
	UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36"
	out_file="test.out"	
	dst=$1
	label=$2

	# curl download 
    test_start_time=`date +%s`
	stats="$res_folder/stats-$label-$test_start_time-$network_ind"
	headers="$res_folder/headers-$label-$test_start_time-$network_ind"
	timeout 15 curl -v -w "type:%{content_type}\tcode:%{response_code}\tremoteIP:%{remote_ip}\tdownload_speed:%{speed_download} Bps\tt_dns:%{time_namelookup} sec\tt_connect:%{time_connect} sec\tt_appconnect:%{time_appconnect} sec\tt_pretransfer:%{time_pretransfer} sec\tt_redirect:%{time_redirect} sec\tt_starttransfer:%{time_starttransfer} sec\tt_total:%{time_total} sec\t\"size_download\":%{size_download} Bytes\t\"size_header\":%{size_header} Bytes\n" -s $dst -o $out_file > $stats  2>$headers
    test_end_time=`date +%s`
    myprint "[CURL] Destination: $dst Label: $label start: $test_start_time, end: $test_end_time"
	gzip $stats
	gzip $headers	
    rm -f $out_file
    sleep 1
}


# Main execution
main() {
    # Parameters
    if [ $# -eq 2 ]; then
        today=$1
        ts=$2
    else 
        today=$(date +%d-%m-%Y)
        ts=$(date +%s)
    fi 

    # # System information
    # hostname=$(hostname)
    # container_id=$(cat /proc/self/cgroup 2>/dev/null | head -n1 | cut -d/ -f3 | cut -c1-12 || echo "unknown")

    # Folder organization 
    res_folder="./results/cdnlogs/$today/$ts"
    mkdir -p "$res_folder"

    # Get network information
    network_type=$(check_network_status)
    network_ind=$(echo "$network_type" | cut -f1 -d"_")

    # CDN tests - same URLs as original but adapted for Linux
    test_download "https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js" "cloudflare"
    test_download "https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js" "google"
    test_download "https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js" "jsdelivr"
    test_download "https://ajax.aspnetcdn.com/ajax/libs/jQuery/jquery-3.6.0.min.js" "microsoft"
    test_download "https://code.jquery.com/jquery-3.6.0.min.js" "jquery"
    test_download "https://www.facebook.com" "facebook"
    

    # Clean up
    rm -f test.out

    myprint "CDN tests completed"
}

# Run main function with all arguments
main "$@"