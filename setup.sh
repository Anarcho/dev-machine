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
    fi
}

# Step 1: Install packages
echo "Installing required packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm hyprland wayland kitty sddm xdg-desktop-portal-hyprland xf86-video-nouveau mesa mkinitcpio
check_status "Package installation"

# Step 2: Enable SDDM
echo "Enabling SDDM service..."
sudo systemctl enable sddm.service
check_status "SDDM service enablement"

# Step 3: Create necessary config directories
echo "Creating config directories..."
mkdir -p ~/.config/{hypr,kitty}
check_status "Config directory creation"

# Step 4: Copy configuration files
echo "Copying configuration files..."
cp ./hyprland.conf ~/.config/hypr/
cp ./kitty.conf ~/.config/kitty/
check_status "Configuration file copying"

# Step 5: Modify mkinitcpio.conf for Nouveau
echo "Checking mkinitcpio.conf for nouveau..."
if ! grep -q "MODULES=(.*nouveau.*)" /etc/mkinitcpio.conf; then
    sudo sed -i '/^MODULES=/s/)/nouveau)/' /etc/mkinitcpio.conf
    check_status "Adding nouveau to mkinitcpio.conf"
else
    echo "Nouveau already present in mkinitcpio.conf"
fi

# Step 6: Rebuild initramfs
echo "Rebuilding initramfs..."
sudo mkinitcpio -P
check_status "Initramfs rebuild"

echo "Setup completed successfully. Please reboot to start using your new Hyprland setup with Nouveau drivers."