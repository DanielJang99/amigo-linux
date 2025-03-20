#!/data/data/com.termux/files/usr/bin/env bash

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

PUBLIC_IP=$(curl -s 'https://api.ipify.org')

# Check if IP was fetched
if [[ -z "$PUBLIC_IP" ]]; then
    echo "Failed to retrieve public IP address."
    exit 0
fi

ASN_INFO=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)

if [[ "$ASN_INFO" == *"AS14593"* ]]; then
    suffix=`date +%d-%m-%Y`
    ts=`date +%s`
    res_dir="mtr_aws/$suffix"
    mkdir -p $res_dir

    num_packets=10

    # Read the aws_servers.txt file and extract IP addresses from the last column
    while IFS=',' read -r region hostname ip; do
        myprint "Running MTR test for region: $region (IP: $ip)"
        sudo mtr -r4wc $num_packets -T -P 12340 $ip > $res_dir/${region}_${ts}.txt 2>&1
        gzip $res_dir/${region}_${ts}.txt
    done < aws_servers.txt 

    myprint "MTR test completed for all regions."
else
    myprint "Current IP ($PUBLIC_IP) is not associated with AS14593."
    myprint "Skipping MTR tests."
fi

