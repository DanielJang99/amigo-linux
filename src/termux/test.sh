#!/bin/bash
## Author: Matteo Varvello 
## Date:   11/10/2021

# import utilities files needed
script_dir=`pwd`
adb_file=$script_dir"/adb-utils.sh"
source $adb_file 

toggle_wifi "off"
toggle_wifi "on"
