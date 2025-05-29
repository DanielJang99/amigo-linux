#!/bin/bash

myprint(){
    timestamp=`date +%s`
    if [ $DEBUG -gt 0 ]
    then
        if [ $# -eq  0 ]
        then
            echo -e "[ERROR][$timestamp]\tMissing string to log!!!"
        else
        	if [ $# -eq  1 ]
			then 
	            echo -e "[$0][$timestamp]\t" $1
			else 
	            echo -e "[$0][$timestamp][$2]\t" $1
			fi 
        fi
    fi
}

# clean a file
clean_file(){
    if [ -f $1 ]
    then
        rm $1
    fi
}


check_network_status() {
    local current_network_type=""
    local is_internet_accessible=false
    local current_network_capabilities=""
    
    # Check if we have any network interfaces up (excluding loopback)
    active_interfaces=$(ip link show | grep -E "state UP" | grep -v "@" | grep -v "lo:" | wc -l)
    
    if [ "$active_interfaces" -eq 0 ]; then
        echo "No active network interfaces found"
        return 1
    fi
    # Get network interface information
    network_info=$(ip route show default 2>/dev/null)
    current_network_capabilities="Network interfaces: $(ip link show | grep -E "state UP" | cut -d: -f2 | tr -d ' ' | tr '\n' ', ')"
    
    # Check for WiFi connection
    if ip address | grep -q "docker"; then
        current_network_type="docker"
    elif command -v iwconfig >/dev/null 2>&1; then
        # Check if any wireless interface is connected
        wifi_status=$(iwconfig 2>/dev/null | grep -E "ESSID|Access Point" | grep -v "off/any" | grep -v "Not-Associated")
        if [ -n "$wifi_status" ]; then
            current_network_type="wifi"
        fi
    else
        # Fallback: check for common wireless interface names
        wireless_interfaces=$(ls /sys/class/net/ | grep -E "^(wlan|wlp|wlo)" 2>/dev/null)
        if [ -n "$wireless_interfaces" ]; then
            for iface in $wireless_interfaces; do
                if [ "$(cat /sys/class/net/$iface/operstate 2>/dev/null)" = "up" ]; then
                    current_network_type="wifi"
                    break
                fi
            done
        fi
    fi
    
    # If not WiFi, check for ethernet
    if [ -z "$current_network_type" ] && [ -n "$network_info" ]; then
        ethernet_interfaces=$(ls /sys/class/net/ | grep -E "^(eth|enp|eno)" 2>/dev/null)
        if [ -n "$ethernet_interfaces" ]; then
            for iface in $ethernet_interfaces; do
                if [ "$(cat /sys/class/net/$iface/operstate 2>/dev/null)" = "up" ]; then
                    current_network_type="ethernet"
                    break
                fi
            done
        fi
    fi

    # Check internet connectivity using Android's method (HTTP 204 check)
    # Android uses these URLs for connectivity validation
    android_check_urls=(
        "http://connectivitycheck.gstatic.com/generate_204"
        "http://clients3.google.com/generate_204" 
        "http://connectivitycheck.android.com/generate_204"
    )
    

    if command -v curl >/dev/null 2>&1; then
        for url in "${android_check_urls[@]}"; do
            # Check for HTTP 204 response (like Android does)
            response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$url" 2>/dev/null)
            if [[ "$response_code" == "20"* ]]; then
                is_internet_accessible=true
                break
            fi
        done
    else
        # Final fallback to ping if no HTTP tools available
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || \
           ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
            is_internet_accessible=true
        fi
    fi

    # # Output results
    # echo "Current Network Type: $current_network_type"
    # echo "Internet Accessible: $is_internet_accessible"
    # echo "Network Type: ${current_network_type}_${is_internet_accessible}"
    # echo "current_network_capabilities: $current_network_capabilities"
    
    echo "${current_network_type}_${is_internet_accessible}" > ".network_status"
    sudo cat ".network_status"
}

get_def_iface() {
    local def_iface="none"
    if ip address | grep -q "docker"; then
        def_iface="docker0"
    else
        def_iface=$(ip link show | grep -E "state UP" | grep -v "@" | head -n 1 | cut -d: -f2)
    fi
    echo "$def_iface" > ".def_iface"
    sudo cat ".def_iface"
}

get_wifi_ssid() {
    local ssid=""

    if command -v iwgetid >/dev/null 2>&1; then
        ssid=$(iwgetid -r 2>/dev/null)
        if [ -n "$ssid" ]; then
            echo "$ssid" > ".wifi_ssid"
            cat ".wifi_ssid"
            return 0
        fi
    fi

    if command -v nmcli >/dev/null 2>&1; then
        ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2)
        if [ -n "$ssid" ]; then
            echo "$ssid" > ".wifi_ssid"
            cat ".wifi_ssid"
            return 0
        fi
    fi
}

get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo "$PUBLIC_IP" > ".public_ip"
    cat ".public_ip"
}

