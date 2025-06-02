## NOTE:  Script to clone repo at docker runtime (avoids caching at build time)
## Author: Daniel (hsj276@nyu.edu)
## Date: 2025-06-02

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

echo "Installation completed!"