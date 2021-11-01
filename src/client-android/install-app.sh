#!/bin/bash
adb -s $2 push $1 /data/local/tmp/
apk_file=`echo $1 | awk -F "/" '{print $NF}'`
echo $apk_file
adb -s $2 shell pm install -t /data/local/tmp/$apk_file
