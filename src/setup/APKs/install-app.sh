#!/bin/bash
if [ $# -ne 2 ] 
then 
	echo "USAGE: $0 device-id apk-file"
	exit -1 
fi 
echo "Pushing $2 to phone..."
adb -s $1 push $2 /data/local/tmp/
apk_file=`echo $2 | awk -F "/" '{print $NF}'`
echo $apk_file
echo "Installing..."
adb -s $1 shell pm install -t /data/local/tmp/$apk_file
