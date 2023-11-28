#!/usr/bin/env python
import sys
from datetime import datetime, timedelta

def main(s):
    device = s.replace("&quot;", "").replace("}","").split("{")[1].replace("</string>","")
    device_infos = device.split(",")
    device_dict={}
    
    for dev_info in device_infos:
        dev_info_split = dev_info.split(":")
        k, v = dev_info_split[0], dev_info_split[1]
        if k == "id":
            device_dict["imei"] = v
        elif k == "name": 
            device_dict["name"] = v
        elif k == "isOffline": 
            device_dict[k] = v
        elif k == "firstLat": 
            device_dict["lat"] = v
        elif k == "firstLong": 
            device_dict["long"] = v
        elif k == "firstAcc": 
            device_dict["acc"] = v
        elif k == "firstTime":
            updated_time_base = datetime.strptime(v, "%Y%m%d%H%M%S")  
            device_dict["lastUpdated"] = updated_time_base + timedelta(hours=4)
    print(device_dict)

    # devices = s.replace("&quot;", "").split("[")[1].split("]")[0].replace("}","").split("{")
    # for device in devices:
    #     if "TAG" not in device:
    #         continue
    #     device_infos = device.split(",")
    #     device_dict = {}
    #     for dev_info in device_infos:
    #         if ":" not in dev_info:
    #             continue
    #         dev_info_split = dev_info.split(":")
    #         k, v = dev_info_split[0], dev_info_split[1]
    #         if k == "id":
    #             device_dict["imei"] = v
    #         elif k == "name": 
    #             device_dict["name"] = v
    #         elif k == "isOffline": 
    #             device_dict[k] = v
    #         elif k == "firstLat": 
    #             device_dict["lat"] = v
    #         elif k == "firstLong": 
    #             device_dict["long"] = v
    #         elif k == "firstAcc": 
    #             device_dict["acc"] = v
    #         elif k == "firstTime":
    #             device_dict["lastUpdated"] = v
    #     print(device_dict)

if '__main__' == __name__:
    main(sys.argv[1])
