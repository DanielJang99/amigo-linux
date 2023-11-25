#!/data/data/com.termux/files/usr/bin/env bash
adb_file=`pwd`"/adb-utils.sh"
source $adb_file

while [ "$#" -gt 0 ]
do
    case "$1" in
        --suffix)
            shift; suffix="$1"; shift;
            ;;
        --t_s)
            shift; t_s="$1"; shift;
            ;;
    esac
done

res_folder="speedtest-cli-logs/${suffix}"
mkdir -p $res_folder
speedtest-cli --json > "${res_folder}/speedtest-$t_s.json"
gzip "${res_folder}/speedtest-$t_s.json"

