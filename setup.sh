#!/bin/bash

LOG_FILE=~/setup.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting setup script with Nouveau drivers and config reset..." $(date)

# Function to check last command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1 failed"
        exit 1
    fi
}

# Step 1: Update package database and upgrade system
echo "Updating package database and upgrading system..."
sudo pacman -Syu --noconfirm
check_status "System update"

# Step 2: Install packages
echo "Installing required packages..."
sudo pacman -S --needed --noconfirm hyprland wayland kitty sddm xdg-desktop-portal-hyprland xf86-video-nouveau mesa mkinitcpio
check_status "Package installation"

# Step 3: Enable SDDM
echo "Enabling SDDM service..."
sudo systemctl enable sddm.service
check_status "SDDM service enablement"

# Step 4: Create necessary config directories
echo "Creating config directories..."
mkdir -p ~/.config/{hypr,kitty}
check_status "Config directory creation"

# Step 5: Delete existing configuration files
echo "Deleting existing configuration files..."
rm -f ~/.config/hypr/hyprland.conf
rm -f ~/.config/kitty/kitty.conf
check_status "Configuration file deletion"

# Step 6: Copy new configuration files
echo "Copying new configuration files..."
cp ./hyprland.conf ~/.config/hypr/
cp ./kitty.conf ~/.config/kitty/
check_status "Configuration file copying"

# Step 7: Modify mkinitcpio.conf for Nouveau
echo "Checking mkinitcpio.conf for nouveau..."
if ! grep -q "MODULES=(.*nouveau.*)" /etc/mkinitcpio.conf; then
    sudo sed -i '/^MODULES=/s/)/nouveau)/' /etc/mkinitcpio.conf
    check_status "Adding nouveau to mkinitcpio.conf"
else
    echo "Nouveau already present in mkinitcpio.conf"
fi

# Step 8: Rebuild initramfs
echo "Rebuilding initramfs..."
sudo mkinitcpio -P
check_status "Initramfs rebuild"

echo "Setup completed successfully. Please reboot to start using your new Hyprland setup with Nouveau drivers and fresh configurations."