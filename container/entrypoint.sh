#!/bin/bash

# Exit on any error
set -e

echo "Starting entrypoint script..."

# Clone the repository
echo "Cloning repository..."
REPO_URL=https://github.com/DanielJang99/amigo-linux.git
REPO_DIR=/amigo-linux
if [ -d "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
    echo "Repository exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
else
    echo "Repository not found, cloning instead..."
    git clone "$REPO_URL"
fi
echo "Repository setup complete!"

# Change to the repository directory
cd $REPO_DIR
cd linux

# Install python packages
pip install -r requirements.txt

# Start SSH service
echo "Starting SSH service..."
service ssh start

# Start cron service
echo "Starting cron service..."
service cron start

echo "All services started successfully."

# Keep the container running
echo "Container is now running in the background..."
tail -f /dev/null 