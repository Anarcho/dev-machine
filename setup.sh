#!/bin/bash

LOG_FILE=~/setup.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting setup script with Nouveau drivers..." $(date)

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
sudo pacman -S --needed --noconfirm hyprland wayland kitty sddm xdg-desktop-portal-hyprland xf86-video-nouveau mesa mkinitcpio wofi
check_status "Package installation"

# Step 3: Enable SDDM
echo "Enabling SDDM service..."
sudo systemctl enable sddm.service
check_status "SDDM service enablement"

# Step 4: Modify mkinitcpio.conf for Nouveau
echo "Checking mkinitcpio.conf for nouveau..."
if ! grep -q "MODULES=(.*nouveau.*)" /etc/mkinitcpio.conf; then
    sudo sed -i '/^MODULES=/s/)/nouveau)/' /etc/mkinitcpio.conf
    check_status "Adding nouveau to mkinitcpio.conf"
else
    echo "Nouveau already present in mkinitcpio.conf"
fi

# Step 5: Rebuild initramfs
echo "Rebuilding initramfs..."
sudo mkinitcpio -P
check_status "Initramfs rebuild"

echo "Setup completed successfully. Please run the config_copy.sh script to set up your configurations, then reboot to start using your new Hyprland setup."