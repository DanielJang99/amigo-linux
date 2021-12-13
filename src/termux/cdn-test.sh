#!/data/data/com.termux/files/usr/bin/bash
## Author: Matteo Varvello (varvello@gmail.com)
## Date: 11-10-2020
## NOTE: Tool to test perf of multiple CDNs

# simple function for logging
DEBUG=1
myprint(){
    timestamp=`date +%s`
    if [ $DEBUG -gt 0 ]
    then
        if [ $# -eq  0 ]
        then
            echo -e "[ERROR][$timestamp]\tMissing string to log!!!"
        else
            if [ $# -eq  1 ]
            then 
                echo -e "[$0][$timestamp]\t" $1
            else 
                echo -e "[$0][$timestamp][$2]\t" $1
            fi 
        fi
    fi
}

# generate data to be POSTed to my server 
generate_post_data(){
  cat <<EOF
	{
	"uid":"${uid}",
	"test_label": "${label}", 
	"file_size_on_disk":"${file_size}",
	"cache_hit":"${cache_hit}",
	"x-served-by":"${x_served}",
	"age":"${age}",
	"type":"${type}",
	"code":"${code}",
	"remoteIP":"${remoteIP}",
	"download_speed":"${download_speed}",
	"t_dns":"${t_dns}",
	"t_connect":"${t_connect}",
	"t_appconnect":"${t_appconnect}",
	"t_pretransfer":"${t_pretransfer}",
	"t_redirect":"${t_redirect}",
	"t_starttransfer":"${t_starttransfer}",
	"t_total":"${t_total}",
	"size_download":"${size_download}",
	"size_header":"${size_header}"
	}
EOF
}


# helper function to test a download 
test_download(){
	# params
	UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36"
	out_file="test.out"	
	dst=$1
	label=$2

	# curl download 
	myprint "[CURL] Destination: $dst Label: $label"
	stats="$res_folder/stats-$label-$ts"
	headers="$res_folder/headers-$label-$ts"
#	echo "curl -v -H \"Accept-Encoding: gzip\" -H 'user-agent: $UA' -w \"@curl-format.txt\" -s $dst -o $out_file"
	#curl -v -H "Accept-Encoding: gzip" -H 'user-agent: $UA' -w "@curl-format.txt" -s $dst -o $out_file > $stats  2>$headers
	timeout 15 curl -v -w "@curl-format.txt" -s $dst -o $out_file > $stats  2>$headers
	gzip $stats
	gzip $headers	

	# stopping here 
	
	# type=`cat "$stats" | head -n 1 | cut -f 1 | cut -f 2 -d ":"`
	# code=`cat "$stats" | head -n 1 |cut -f 2 | cut -f 2 -d ":"`
	# remoteIP=`cat "$stats" | head -n 1 |cut -f 3 | cut -f 2 -d ":"`
	# download_speed=`cat "$stats" | head -n 1 |cut -f 4 | cut -f 2 -d ":"`
	# t_dns=`cat "$stats" | head -n 1 |cut -f 5 | cut -f 2 -d ":"`
	# t_connect=`cat "$stats" | head -n 1 | cut -f 6 | cut -f 2 -d ":"`
	# t_appconnect=`cat "$stats" | head -n 1 | cut -f 7 | cut -f 2 -d ":"`
	# t_pretransfer=`cat "$stats" | head -n 1 | cut -f 8 | cut -f 2 -d ":"`
	# t_redirect=`cat "$stats" | head -n 1 | cut -f 9 | cut -f 2 -d ":"`
	# t_starttransfer=`cat "$stats" | head -n 1 | cut -f 10 | cut -f 2 -d ":"`
	# t_total=`cat "$stats" | head -n 1 | cut -f 11 | cut -f 2 -d ":"`
	# size_download=`cat "$stats" | head -n 1 | cut -f 12 | cut -f 2 -d ":"`
	# size_header=`cat "$stats" | head -n 1 | cut -f 13 | cut -f 2 -d ":"`
	
	# # check return code 
	# cache_hit="N/A" 
	# x_served="N/A"
	# age="N/A"
	# if [ -f "$headers" ] 
	# then
	# 	tr '\r' '\n' < "$headers" > t
	# 	mv t "$headers"
	# 	x_served=`cat "$headers" | grep "x-amz-cf-pop\|x-served-by" | awk '{print $NF}'`
	# 	age=`cat "$headers" | grep "age:" | awk '{print $NF}'`
	# 	cat "$headers" | grep -i "HIT" > /dev/null
	# 	if [ $? -eq 0 ] 
	# 	then 
	# 		cache_hit="True"
	# 	else 
	# 		cache_hit="False"
	# 	fi 
	# fi 
	
	# # logging 
	# t_end=`date +%s`
	# let "t_passed = t_end - t_start"
	# if [ $isMacOS == "true" ] 
	# then
	# 	file_size=`stat $out_file  | cut -f 8 -d " "`
	# else 
	# 	file_size=`stat $out_file | grep "Size"  | cut -f 1 | awk -F ":" '{print int($2)}'`
	# fi 
	# myprint "File:$out_file\t Size:$file_size\tCache-HIT:$cache_hit\tX-served-by:$x_served\tAge:$age"

	# report to the server
	# echo "$(generate_post_data)" 
	#curl  -H "Content-Type:application/json" -X POST -d "$(generate_post_data)" https://nj.batterylab.dev:8080/dCURL
}


# check for macOS
isMacOS="false"
uname -a | grep "Darwin" > /dev/null
if [ $? -eq 0 ]
then
	isMacOS="true"
fi 

# common test identifier 
if [ $# -eq 2 ]
then
	uid=$1
	ts=$2
else 
    uid=`date +%d-%m-%Y`
    ts=`date +%s`
fi 

# folder organiztion 
res_folder="./cdnlogs/$uid"
mkdir -p $res_folder 

# CDN tests
myprint "Starting CDN tests..."
test_download "https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js" "cloudflare"
test_download "https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js" "google-comp-quic"
test_download "https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js" "jsdelivr"
test_download "https://ajax.aspnetcdn.com/ajax/jQuery/jquery-3.6.0.min.js" "microsoft"
test_download "https://code.jquery.com/jquery-3.6.0.min.js" "jquery"
#test_download "https://www.google.com" "google-comp-quic"      # skipping cause size diff with H3
#test_download "https://www.youtube.com" "youtube-comp-quic"    # skipping cause size diff with H3
test_download "https://www.facebook.com" "facebook-comp-quic"
