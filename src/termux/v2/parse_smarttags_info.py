#!/usr/bin/env python
import sys

def main(s):
    devices = s.replace("&quot;", "").replace("}","").split("{")
    for device in devices:
        if "TAG" not in device:
            continue 
        device_infos = device.split(",")
        name=""
        fLat = ""
        fLong = ""
        fTime = ""
        fAcc = ""
        for dev_info in device_infos:
            if "name" in dev_info:
                name = dev_info.split(":")[1]
            if "firstLong" in dev_info:
                fLong  = dev_info.split(":")[1]
            if "firstLat" in dev_info:
                fLat  = dev_info.split(":")[1]
            if "firstTime" in dev_info:
                fTime = dev_info.split(":")[1]
            if "firstAcc" in dev_info:
                fAcc = dev_info.split(":")[1]
        if "ST" in name:
            device_dict = {
                "name": name, 
                "Latitude": fLat, 
                "Longitude": fLong, 
                "Accuracy": fAcc, 
                "lastUpdated": fTime
            }
            print(device_dict)
        

if '__main__' == __name__:
    main(sys.argv[1])
