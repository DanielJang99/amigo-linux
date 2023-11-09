#!/usr/bin/env python
import sys

def main(s):
    devices = s.replace("&quot;", "").split('[')[1].split(']')[0].replace("}","").split("{")
    for device in devices:
        if "TAG" not in device:
            continue 
        device_infos = device.split(",")
        name=""
        fLat = ""
        fLong = ""
        fTime = ""
        fAcc = ""
        sLat = ""
        sLong = ""
        sTime = ""
        sAcc = ""
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
            if "secondLat" in dev_info:
                sLat = dev_info.split(":")[1]
            if "secondLong" in dev_info:
                sLong  = dev_info.split(":")[1]
            if "secondTime" in dev_info:
                sTime  = dev_info.split(":")[1]
            if "secondAcc" in dev_info:
                sAcc  = dev_info.split(":")[1]
        print(name, fLat, fLong, fTime, fAcc, sLat, sLong, sTime, sAcc)

if '__main__' == __name__:
    main(sys.argv[1])
