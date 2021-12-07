#!/data/data/com.termux/files/usr/bin/env bash
timestamp=`date +%s`
echo -e "[$0][$timestamp]\tStart monitoring CPU (PID: $$)"
echo "true" > ".cpu_monitor"
to_monitor=`cat ".cpu_monitor"`
to_monitor="true"
prev_total=0
prev_idle=0
while [ $to_monitor == "true" ]
do
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	prev_idle=`echo "$result" | cut -f 2`
	prev_total=`echo "$result" | cut -f 3`
	sleep 2
	result=`sudo cat /proc/stat | head -n 1 | awk -v prev_total=$prev_total -v prev_idle=$prev_idle '{idle=$5; total=0; for (i=2; i<=NF; i++) total+=$i; print (1-(idle-prev_idle)/(total-prev_total))*100"%\t"idle"\t"total}'`
	echo "$result" | cut -f 1 | cut -f 1 -d "%" > ".cpu-usage"
	sleep 2
	to_monitor=`cat ".cpu_monitor"`
done
