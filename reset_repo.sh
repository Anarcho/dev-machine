#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Your repo URL
REPO_URL="https://github.com/anarcho/dev-machine.git"
REPO_DIR="$HOME/your-repo-name"

echo -e "$CNT Resetting repository..."

# Check if the repo directory exists
if [ -d "$REPO_DIR" ]; then
    echo -e "$CNT Removing existing repository..."
    rm -rf "$REPO_DIR"
    echo -e "$COK Existing repository removed."
else
    echo -e "$CNT Repository directory not found. Proceeding with clone."
fi

# Clone the repository
echo -e "$CNT Cloning repository..."
git clone "$REPO_URL" "$REPO_DIR"
if [ $? -ne 0 ]; then
    echo -e "$CER Failed to clone repository. Exiting."
    exit 1
fi
echo -e "$COK Repository cloned successfully."

# Change to the repo directory
cd "$REPO_DIR" || { echo -e "$CER Failed to change to repository directory. Exiting."; exit 1; }

# Make setup.sh executable
echo -e "$CNT Making setup.sh executable..."
chmod +x setup.sh
echo -e "$COK setup.sh is now executable."

# Run setup.sh
echo -e "$CNT Running setup.sh..."
./setup.sh

echo -e "$COK Repository reset and setup process completed."