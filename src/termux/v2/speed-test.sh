#!/data/data/com.termux/files/usr/bin/env bash
## Author: Daniel Jang (hsj276@nyu.edu)
## Date: 11/24/2023

adb_file=`pwd`"/adb-utils.sh"
source $adb_file

while [ "$#" -gt 0 ]
do
    case "$1" in
        --suffix)
            shift; suffix="$1"; shift;
            ;;
        --id)
            shift; id="$1"; shift;
            ;;
        -*) 
            echo "ERROR: Unknown option $1"
    esac
done

network_type=`get_network_type`
network_ind=`echo $network_type | cut -f 1 -d "_"`
id="${id}_${network_ind}"
res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$id.json"
gzip "${res_folder}/speedtest-$id.json"

