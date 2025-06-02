## NOTE:  Script to install python packages
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-06-02

# Upgrade pip
echo "Upgrading pip..."
python3 -m pip install --upgrade pip

# Install Python packages
echo "Installing Python packages..."
pip3 install -r requirements.txt