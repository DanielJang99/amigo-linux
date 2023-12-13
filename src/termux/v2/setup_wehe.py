#!/usr/bin/env python
import sys
import xml.etree.ElementTree as ET

def main():
    names=list()
    selected=list()
    foundTests=0
    tree = ET.parse("window_dump.xml")
    root = tree.getroot()
    enable_flag = False
    for child in root.iter():
        if child.attrib.get("resource-id") == "mobi.meddle.wehe:id/app_name_textview": 
            name = child.attrib.get("text")
            if name == "Disney+" or name == "Facebook Video":
                enable_flag = True
            else:
                enable_flag = False
            names.append(name)
        elif child.attrib.get("resource-id") == "mobi.meddle.wehe:id/isSelectedSwitch":
            isSelected = child.attrib.get("checked")
            if (enable_flag == False and isSelected == "true") or (enable_flag == True and isSelected == "false"): 
                print(child.attrib.get("bounds").replace("[","").split("]")[0].replace(",", " "))
            selected.append(child.attrib.get("checked")) 
            foundTests+=1
    print(foundTests)
    # print(names)
    # print(selected)
    # print(names[:len(selected)])
    # print(selected)


if '__main__' == __name__:
    main()

