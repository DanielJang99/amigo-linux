#!/bin/bash

# install and configure git
sudo apt-get install -y git
git config --global user.email "bravello@gmail.com"
git config --global user.name "Batterylab Team"


# install and setup tigervnc
hash tigervncserver > /dev/null 2>&1
if [ $? -eq 1 ]
then
    sudo apt-get install -y tigervnc-standalone-server

    # update xstartup file
    mkdir -p $HOME"/.vnc"
    if [ -f xstartup ]
    then
        echo "-----> copying xstartup: `pwd`"
        cp xstartup $HOME"/.vnc"
    else
        echo "No xstartup was provided. Default is being used"
    fi
else
    echo "tigervncserver already installed. Nothing to do."
fi

# install scrcpy (Android mirroring)
hash scrcpy > /dev/null 2>&1
if [ $? -eq 1 ]
then
	# get the code 
	git clone https://github.com/Genymobile/scrcpy
	
	# runtime dependencies
	sudo apt install -y ffmpeg libsdl2-2.0.0

	# client build dependencies
	sudo apt install -y make gcc pkg-config ninja-build libavcodec-dev libavformat-dev libavutil-dev libsdl2-dev cmake  libavdevice-dev openjdk-8-jdk 
	
	# install meson
	sudo apt install -y meson
	# NOTE: if version of meson is too old -- install via pip3 (watch for PATH)
	#pip3 install meson	

	# compile prebuild 
	cd scrcpy
	curr_dir=`pwd`
	if [ -d "x" ] 
	then 
		rm -rf "x"
	fi 	
	jar_url=`cat BUILD.md  | grep "scrcpy-server" | grep "http" | cut -f 2 -d " "`
	scrcpy_jar_file="scrcpy-server.jar"
	echo "Using pre-server built: $jar_url"
	wget $jar_url -O $scrcpy_jar_file
	echo "meson x --buildtype release --strip -Db_lto=true -Dprebuilt_server=$curr_dir"/"$scrcpy_jar_file"
	meson x --buildtype release --strip -Db_lto=true -Dprebuilt_server=$curr_dir"/"$scrcpy_jar_file
	#/home/pi/.local/bin/meson x --buildtype release --strip -Db_lto=true -Dprebuilt_server=$curr_dir"/"$scrcpy_jar_file
	#/usr/local/bin/meson x --buildtype release --strip -Db_lto=true -Dprebuilt_server=$curr_dir"/"$scrcpy_jar_file
	cd x 
	ninja 
	sudo ninja install
else 
	echo "scrcpy (Android mirroring) already installed. Nothing to do"
fi 

# install noVNC
#no_vnc_vrs="1.2.0"                          # FIXME: new version has issues with my code 
no_vnc_vrs="1.0.0"                           # no VNC version to install
no_vnc_folder="./noVNC-"$no_vnc_vrs          # path for noVNC tool
if [ ! -d $no_vnc_folder ]
then 
  wget https://github.com/novnc/noVNC/archive/v$no_vnc_vrs.tar.gz
  tar xzvf v$no_vnc_vrs.tar.gz
else 
	echo "noVNC already installed. Nothing to do" 
fi 
