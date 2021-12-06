#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical

# stop sshd in case it was running (if fails just means for sure no SSH so that is ok for us)
sv stop sshd > /dev/null 2>&1

apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
apt-get -qy autoclean

# install and start ssh 
pkg install -y openssh cronie termux-services
sshd 
