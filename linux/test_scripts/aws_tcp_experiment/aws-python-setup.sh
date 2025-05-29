#!/bin/bash
sudo dnf install python3
sudo dnf install python3-numpy -y
python3 -m ensurepip --default-pip
python3 -m pip install --user matplotlib
