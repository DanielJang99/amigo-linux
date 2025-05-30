# Upgrade pip
echo "Upgrading pip..."
python3 -m pip install --upgrade pip

# Install Python packages
echo "Installing Python packages..."
pip3 install speedtest-cli

REPO_URL=https://github.com/DanielJang99/amigo-linux.git
REPO_DIR=/amigo-linux
if [ -d "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
    echo "Repository exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
else
    echo "Repository not found, cloning..."
    git clone "$REPO_URL"
fi
echo "Repository setup complete!"

echo "Installation completed!"