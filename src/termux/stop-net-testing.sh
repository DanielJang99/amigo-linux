#!/data/data/com.termux/files/usr/bin/env bash
for pid in `ps aux | grep 'youtube-test\|net-testing\|web-test'  | grep -v grep | awk '{print $2}'`
do 
	kill -9 $pid
done
