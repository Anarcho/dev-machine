#!/bin/bash

LOG_FILE=~/config_copy.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting configuration copy script..." $(date)

# Function to check last command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1 failed"
        exit 1
    fi
}

# Step 1: Create necessary config directories
echo "Creating config directories..."
mkdir -p ~/.config/{hypr,kitty}
check_status "Config directory creation"

# Step 2: Delete existing configuration files
echo "Deleting existing configuration files..."
rm -f ~/.config/hypr/hyprland.conf
rm -f ~/.config/kitty/kitty.conf
check_status "Configuration file deletion"

# Step 3: Copy new configuration files
echo "Copying new configuration files..."
cp ./hyprland.conf ~/.config/hypr/
cp ./kitty.conf ~/.config/kitty/
check_status "Configuration file copying"

echo "Configuration copy completed successfully. You can now reboot to start using your new Hyprland setup with fresh configurations."