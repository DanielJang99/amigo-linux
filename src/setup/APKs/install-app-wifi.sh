#!/bin/bash
if [ $# -ne 2 ] 
then 
	echo "USAGE: $0 wifi-ip apk-file"
	exit -1 
fi 
echo "Pushing $2 to phone via wifi ($1)..."
scp -i ../id_rsa_mobile -P 8022 $2 $1:
apk_file=`echo $2 | awk -F "/" '{print $NF}'`
echo $apk_file
echo "Installing $apk_file..."
ssh -i ../id_rsa_mobile -p 8022 $1 "sudo pm install -t $apk_file"
ssh -i ../id_rsa_mobile -p 8022 $1 "rm $apk_file"
