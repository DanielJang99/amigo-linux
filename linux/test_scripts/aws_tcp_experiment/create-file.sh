#!/bin/bash
if [ $# -ne 2 ] 
then 
	echo "USAGE: $0 fileName MB"
	exit -1 
fi 
if [ ! -f $1 ] 
then 
	dd if=/dev/zero of=$1 bs=1M count=$2
fi 
