#!/usr/bin/env python
import sys

def main(s):
    experiments = s.replace("&quot;", "").split("[")[1].split("]")[0].replace("}","").split("{")[1:]
    for exp in experiments:
        experiments_dict={}
        exp_split = exp.split(",")
        for es in exp_split:
            if ":" not in es:
                continue
            es_kv = es.split(":")
            k,v = es_kv[0], es_kv[1]
            experiments_dict[k] = v
        print(experiments_dict)


if '__main__' == __name__:
    f = open("ReplayActPrefsFile.xml", "r")
    # main(sys.argv[1])
    main(f.read())
