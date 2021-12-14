#!/bin/bash
pkg upgrade -y
pkg install -y termux-api tsu root-repo mtr python tcpdump tshark ffmpeg imagemagick
python -m pip install --upgrade pip
pip install speedtest-cli
pip install wheel
pip install pillow
cd ../termux 
./check-visual.sh
