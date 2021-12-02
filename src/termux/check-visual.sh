#!/data/data/com.termux/files/usr/bin/env bash
if [ ! -d "visualmetrics" ]
then
    git clone https://github.com/WPO-Foundation/visualmetrics
	cd visualmetrics
else 
	cd visualmetrics
	git pull
fi 
python visualmetrics.py --check
cd - > /dev/null 2>&1
