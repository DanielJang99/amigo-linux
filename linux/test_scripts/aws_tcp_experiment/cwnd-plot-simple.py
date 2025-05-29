import re
import sys 
import os 
import json 
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['pdf.fonttype'] = 42
matplotlib.rcParams['ps.fonttype']  = 42
matplotlib.use('Agg')
from matplotlib import rcParams
rcParams.update({'figure.autolayout': True})
rcParams.update({'errorbar.capsize': 2})

# increase font for plotting
font = {'weight' : 'medium',
        'size'   : 16}
matplotlib.rc('font', **font)

def load_json(filename):
    """Load JSON data from a file."""
    with open(filename, 'r') as file:
        return json.load(file)

def save_json(data, filename):
    """Save JSON data to a file."""
    with open(filename, 'w') as file:
        json.dump(data, file, indent=4)
        #print(json.dumps(data, indent=4))
        #json.dump(data, file, indent=4, separators=(",", ":"), ensure_ascii=False)
        #json.dump(data, file, indent=2, separators=(",", ": "), ensure_ascii=False)

def list_to_comma_separated_string(lst):
    """Convert a list to a comma-separated string."""
    return ', '.join(map(str, lst))

def add_to_json(time_values, cwnd_values, retrans_values, file_duration, goodput, epoch_time, c, r, pred_error, filename = "experiments.json"):
    print("Loading:", filename)
    data = load_json(filename)
    # Find the matching entry
    #for entry in full_data['results']:
    for entry in data['results']:    
        #print(type(entry["epoch_time"]), type(entry["c"]), type(entry["r"]), type(epoch_time), type(c), type(r))
        if entry["epoch_time"] == epoch_time and entry["c"] == c and entry["r"] == r:
            # Add the extra fields to the entry
            entry["time_values"] = list_to_comma_separated_string(time_values)
            entry["cwnd_values"] = list_to_comma_separated_string(cwnd_values)
            entry["retrans_values"] = list_to_comma_separated_string(retrans_values)            
            entry["file_duration"]  = file_duration
            entry["goodput"]        = goodput
            entry["file_size"]      = file_size
            entry["pred_error"]     = pred_error
            break
    else:
        print(f"No matching entry found for epoch_time={epoch_time}, c={c}, r={r}")
        return

    # Save the updated data back to the file
    save_json(data, filename)
    print(f"Updated entry for epoch_time={epoch_time}, c={c}, r={r} saved to {filename}")

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

# global parameters
color_list  = ['red', 'blue', 'green', 'magenta', 'black', 'purple', 'orange', 'yellow', 'cyan', 'gray',lighten_color('red'), lighten_color('blue'), lighten_color('green'), lighten_color('magenta'), lighten_color('black'), lighten_color('purple'), lighten_color('orange') ]    # colors supported
style_list  = ['solid', 'dashed', 'dotted']              # styles of plots  supported
marker_list = ['v', 'h', 'D', '8', '+' ]                 # list of markers supported
space_between_boxplots = 5
boxplot_width = 3
ext = 'pdf'
color_dict = {}
color_dict['CC_RENO']  = lighten_color('red')
color_dict['CC_CUBIC'] = lighten_color('blue')
color_dict['CC_BBR']   = lighten_color('green')
color_dict['CC_BBR2']  = lighten_color('magenta')
color_dict['CC_CUBIC_HYSTART'] = 'blue'

# helper to convert sending rate into float
def convert_to_float(value):
    # Split the numeric part and the unit
    if 'Mbps' in value:
        return float(value.replace('Mbps', ''))  # Keep as Mbps
    elif 'Kbps' in value:
        return float(value.replace('Kbps', '')) / 1000  # Convert Kbps to Mbps
    elif 'kbps' in value:
        return float(value.replace('kbps', '')) / 1000  # Convert kbps to Mbps    
    elif 'Gbps' in value:
        return float(value.replace('Gbps', '')) * 1000  # Convert Gbps to Mbps
    elif 'bps' in value:
        return float(value.replace('bps', '')) / 1_000_000  # Convert bps to Mbps
    else:
        raise ValueError(f"Unknown unit in {value}")

# Parse the log data
def parse_log_data(log_data, cc):
    adv_rx_win_values = []
    time_values = []
    cwnd_values = []
    ssthresh_values = []
    retrans_values = []    
    rto_values = []
    bytes_sent_values = []
    bytes_retrans_values = []
    minRTT_values = []
    total_retrans_values = []
    deliverRate_values = []
    firstTime = 0
    
    # hystart fix
    if 'hystart' in cc: 
        cc = 'cubic'
    
    # iterate on each line
    for line in log_data: 
        if cc in line:
            fields = line.split(' ')
            if firstTime == 0:
                time_values.append(0)
                firstTime = int(fields[0])            
            else:
                time_values.append((int(fields[0]) - firstTime)/1000)
            dummySsthresh = True
            dummyRetrans  = True
            dummyBytes = True
            dummyBytesRet = True
            dummyRTT  = True
            dummyRate = True
            dummySndWnd = True
            #for f in fields:
            for i, f in enumerate(fields):
                # NOTE: this is not always visible (annoying)
                if 'snd_wnd' in f: 
                    adv_rx_win = int(f.split(':')[1])
                    adv_rx_win_values.append(adv_rx_win)
                    dummySndWnd = False 
                if 'cwnd' in f and 'gain' not in f: 
                    cwnd = int(f.split(':')[1])
                    cwnd_values.append(cwnd)
                if 'ssthresh' in f and 'rcv_ssthresh' not in f: 
                    ssthresh = int(f.split(':')[1])
                    ssthresh_values.append(ssthresh)
                    dummySsthresh = False 
                if 'retrans' in f and 'bytes' not in f: 
                    # Example 0/196 0: currently no outstanding (unacknowledged) retransmissions 
                    # 196: total number of segments that have been retransmitted.                     
                    ff = f.split(':')[1].split('/')
                    retrans = int(ff[0])
                    tot_retrans = int(ff[1])                    
                    retrans_values.append(retrans)
                    total_retrans_values.append(tot_retrans)
                    dummyRetrans  = False 
                if 'rto' in f: 
                    rto = float(f.split(':')[1])
                    rto_values.append(rto)
                if 'bytes_sent' in f: 
                    bytes_sent = float(int(f.split(':')[1])/1000000)
                    bytes_sent_values.append(bytes_sent)
                    dummyBytes  = False 
                if 'bytes_retrans' in f: 
                    bytes_retrans = float(int(f.split(':')[1])/1000000)
                    bytes_retrans_values.append(bytes_retrans)
                    dummyBytesRet  = False 
                if 'minrtt' in f: 
                    minRTT = float(f.split(':')[1])
                    minRTT_values.append(minRTT)
                    dummyRTT  = False
                if 'delivery_rate' in f:
                    deliverRate = convert_to_float(fields[i + 1])                    
                    deliverRate_values.append(deliverRate)
                    dummyRate = False
            if dummySndWnd:
                 adv_rx_win_values.append(0)            
            if dummySsthresh:
                 ssthresh_values.append(0)
            if dummyRetrans:
                 retrans_values.append(0)
                 total_retrans_values.append(0)
            if dummyBytes:
                 bytes_sent_values.append(0)
            if dummyBytesRet:
                bytes_retrans_values.append(0)
            if dummyRTT: 
                minRTT_values.append(0)
            if dummyRate: 
                deliverRate_values.append(0)
    
    print("parse_log_data completed")
    return time_values, cwnd_values, retrans_values, ssthresh_values, rto_values, bytes_sent_values, bytes_retrans_values, minRTT_values, total_retrans_values, deliverRate_values, firstTime, adv_rx_win_values

# Function to read log file
def read_log_file(filename):
    with open(filename) as file:
        lines = [line.rstrip() for line in file]
    return lines

# Plotting function with vertical lines every N seconds and a single label for "handover"
def generic_time_plot(time_values, values, plot_file, x_label, y_label, title = None, more_values = None, label = None, more_label = None):

    #plt.figure(figsize=(10, 6))
    plt.figure()
    N = 2

    # Plot the main values
    plt.plot(time_values[::N], values[::N], marker='o', label=label, color = lighten_color('blue'))
    
    # Plot the additional values if provided
    if more_values is not None:
        plt.plot(time_values[::N], more_values[::N], marker='x', label=more_label, color = lighten_color('orange'))
    
    
    # Add title and labels
    if title is not None:
        plt.title(title)
    if label is not None or more_label is not None: 
        plt.legend()
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.grid(True)
    
    # Save the plot to a file
    plt.savefig(plot_file)
    print("Check plot: ", plot_file)

# Call the main function with the log file path
if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage:", sys.argv[0], "trace-file file_duration goodput file_size [json_file]")
        sys.exit(-1)
    log_filename   = sys.argv[1]
    file_duration  = float(sys.argv[2])
    goodput        = float(sys.argv[3])
    file_size      = float(sys.argv[4])
    json_file      = ''
    #json_file      = sys.argv[5]    ##NOTE: would need fixing, left if u want to modify
    base_folder    = os.path.dirname(log_filename)
    fields = base_folder.split('/')
    exp_id = fields[1]
    cc = fields[2]
    num_run = int(fields[3])
    log_data = read_log_file(log_filename)
    time_values, cwnd_values, retrans_values, ssthresh_values, rto_values, bytes_sent_values, bytes_retrans_values, minRTT_values, total_retrans_values, deliverRate_values, firstTime, adv_rx_win_values = parse_log_data(log_data, cc)
    
    # Add to JSON for master plot (if exists)
    ##NOTE: would need fixing, left if u want to modify
    if os.path.exists(json_file):
        add_to_json(time_values, cwnd_values, retrans_values, file_duration, goodput, exp_id, cc, num_run,  pred_error, json_file)
    
    # Plotting
    generic_time_plot(time_values, cwnd_values, base_folder + '/cwnd-time.' + ext, 'Time (sec)', 'CWND/SSTRESH (#)', None, ssthresh_values, 'CWND', 'SSTRESH')
    generic_time_plot(time_values, retrans_values, base_folder + '/retr-time.' + ext, 'Time (sec)', 'Retransmissions (#)', None, total_retrans_values, 'Current (#)', 'Total (#)')
    generic_time_plot(time_values, rto_values, base_folder + '/RTO-time.' + ext, 'Time (sec)', 'Time (ms)', None, minRTT_values, 'RTO (ms)', 'MinRTT (ms)')
    generic_time_plot(time_values, bytes_sent_values, base_folder + '/bytes-sent-time.' + ext, 'Time (sec)', 'Bytes (MB)', None, bytes_retrans_values, 'Bytes Sent (MB)', 'Bytes Retransmitted (MB)')
    generic_time_plot(time_values, deliverRate_values, base_folder + '/delivery-rate.' + ext, 'Time (sec)', 'Delivery Rate (Mbps)', None, None, None, None)