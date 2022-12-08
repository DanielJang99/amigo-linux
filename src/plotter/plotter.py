#!/usr/bin/python
## Plotting script 
## Author: Matteo Varvello 
import os 
import sys
import numpy as np
import time
import matplotlib
matplotlib.rcParams['pdf.fonttype'] = 42
matplotlib.rcParams['ps.fonttype']  = 42
#matplotlib.rcParams['text.usetex'] = True
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import rcParams
rcParams.update({'figure.autolayout': True})
rcParams.update({'errorbar.capsize': 2})
from pylab import *
from os.path import isfile, join, isdir
from collections import defaultdict
from datetime import datetime
from os import listdir
from os.path import isfile, join
import json 
import hashlib
from matplotlib import ticker
import matplotlib.patches as patches

# get name of the script 
script_name = os.path.basename(__file__)

# remove scientfic notation 
formatter = ticker.ScalarFormatter(useMathText = False)
formatter.set_scientific(False) 

# simple helper to lighten a color
def lighten_color(color, amount=0.5):
    import matplotlib.colors as mc
    import colorsys
    try:
        c = mc.cnames[color]
    except:
        c = color
    c = colorsys.rgb_to_hls(*mc.to_rgb(c))
    return colorsys.hls_to_rgb(c[0], 1 - amount * (1 - c[1]), c[2])

# increase font 
font = {'weight' : 'medium',
        'size'   : 16}
matplotlib.rc('font', **font)

# global parameters
color       = ['red', 'blue', 'green', 'magenta', 'black', 'purple', 'orange', 'yellow', 'cyan', 'gray',lighten_color('red'), lighten_color('blue'), lighten_color('green'), lighten_color('magenta'), lighten_color('black'), lighten_color('purple'), lighten_color('orange') ]    # colors supported
style       = ['solid', 'dashed', 'dotted']              # styles of plots  supported
marker_list = ['v', 'h', 'D', '8', '+' ]                 # list of markers supported
width = 0.2   # width for barplot 
bar_colors   = []  
patterns = [ "", "oo", "o" , "x", "+" , "|" , "-" , "+" , "x", "o", "O", ".", "*" ]
bar_patterns  = [ "", "", "", "", "", "", "", "", "", "", "o" ,"o" ,"o" ,"o" ,"o" ,"o"]
boxplot_width = 3
space_between_boxplots = 3 
space_between_barplots = 0.05
unknow_ports = {}

# plot CDF of input array 
def cdfplot(vals):
    num = len(vals)
    y_val = np.array(range(num))/float(num)
    x_val = np.array(sorted(vals, key = float))
    curve = plot(x_val, y_val)
    return curve


def cdfplot_new(data):
    num_bins = 20
    counts, bin_edges = np.histogram (data, bins=num_bins, normed=True)
    cdf = np.cumsum (counts)
    curve = plt.plot (bin_edges[1:], cdf/cdf[-1])
    return curve


# function for setting the colors of the box plots pairs
def setBoxColors(bp, c, h):
    bp['boxes'][0].set(facecolor = c)
    bp['boxes'][0].set(hatch = h)
    setp(bp['caps'][0],      color = c)
    setp(bp['caps'][1],      color = c)                                
    setp(bp['whiskers'][0],  color = c, linestyle =  'dashed')
    setp(bp['whiskers'][1],  color = c, linestyle =  'dashed')                                
    setp(bp['medians'][0],   color = 'black')
            

# main goes here 
def main():
    # common parameters 
    #ext = 'pdf'    
    ext = 'png'    
    plot_folder  = 'plots/' 
    app_list = ['zoom', 'meet', 'webex']

    # figure handlers 
    fig_dns  =  plt.figure()
    
    # read input 
    log_file = sys.argv[1]
    if not os.path.isdir(plot_folder):
        os.mkdir(plot_folder);
    if not isfile(log_file): 
        print("ERROR. Something is wrong. Missing file %s" %(log_file))
        return -1 
       
    # parse log file
    dns = {} 
    with open(log_file) as f:
        lines = f.readlines()
    for line in lines: 
        fields = line.split(' ') 
        dns_server = fields[0]
        if dns_server == ''  or '192.168' in dns_server: 
            continue
        try: 
            dns_dur = float(fields[1])
        except: 
            continue
        if dns_dur > 2000: 
            print("Skipping line %s" %(line))
            continue
        if dns_server not in dns: 
            dns[dns_server] = []
        dns[dns_server].append(dns_dur)


    # do the plotting 
    for key in dns: 
        num = str(len(dns[key]))
        if len(dns[key]) < 100: 
            print("Skipping %s too little samples: %d" %(key, len(dns[key])))
        else: 
            curve = cdfplot(dns[key])        
            plt.setp(curve, linewidth = 3, label = key + ' - N:' + num)
    ax = plt.gca()    
    ax.set_xscale('log')    
    ylabel('CDF (0-1)')
    xlabel('DNS Duration (ms)')
    xlim([1, 1000])
    plt.grid(True)
    plt.legend(loc = 'upper left', fontsize = 8)
    plot_file = plot_folder + "/dns." + ext    
    savefig(plot_file)
    print("Check file %s: " %(plot_file))

# call main here
if __name__=="__main__":
    main()  