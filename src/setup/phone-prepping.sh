#!/bin/bash
    # upgrade 
    pkg upgrade -y 

    # install and setup vim (just in case)
    pkg install -y vim
    # TODO 

    # install mtr 
    pkg install -y root-repo
    pkg install -y mtr

    # install python and upgrade pip 
    pkg install python3
    python -m pip install --upgrade pip
    
    # install speedtest-cli    
    pip install speedtest-cli    
    
    # traffic collection 
    pkg install -y tcpdump

    # video analysis 
    pkg install -y ffmpeg 
    echo "WARNING -- next command will take some time..."
    pip install pillow pyssim

    ############################ TESTING 
    # aioquic 
    # pkg install rust
    # pip install wheel # TOBETESTED
    # git clone git@github.com:aiortc/aioquic.git
    # cd aioquic 
    # pip install -e .
    # pip install asgiref dnslib httpbin starlette wsproto


    #pkg install miniupnpc
    #pkg install iperf3
    #pkg install wpa-supplicant
    #pkg install wireless-tools
