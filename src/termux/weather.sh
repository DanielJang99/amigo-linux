#!/bin/bash
log_file=".weather-log"
while true 
do
    # m) use metric - 0) just current weather
    curl -q wttr.in/?m0 > $log_file 2>/dev/null
    line_counter=1
    echo "Time:`date`"
    while read line 
    do 
        case $line_counter in
            1)
                location=`echo $line | cut -f 2 -d ":"`
                echo "Location:$location"
                ;;
            3)
                weather=`echo $line | cut -f 2 -d "/"`
                echo "WeatherInfo:$weather"
                ;;
            4)
                temp=`echo $line | awk '{print $(NF-1)}'` 
                echo "Temperature:$temp"
                ;;
            5)
                wind=`echo $line | awk '{print $(NF-1) $NF}'`                
                echo "Wind:$wind"
                ;;
            6)
                distance=`echo $line | awk '{print $(NF-1) $NF}'`                
                echo "Distance:$distance"
                ;;
            7)
                rain=`echo $line | awk '{print $(NF-1) $NF}'`                
                echo "Rain:$rain"
                ;;
        esac
        let "line_counter++"
    done < $log_file
    sleep 300
done