#!/bin/bash

# Update system packages
sudo pacman -Syu --noconfirm

# Install necessary packages for Wayland, Hyprland, Nouveau drivers, and SDDM
sudo pacman -S hyprland wayland wl-clipboard xorg-xwayland polkit-kde-agent grim slurp qt5-wayland qt6-wayland \
  rofi-wayland waybar swaylock sddm xf86-video-nouveau brightnessctl light kitty --noconfirm

# Enable SDDM
sudo systemctl enable sddm.service

# Install Papirus icon theme and noto-fonts-emoji for better appearance
sudo pacman -S papirus-icon-theme noto-fonts-emoji --noconfirm

# Create necessary config directories if they don't exist
mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/rofi
mkdir -p ~/.config/kitty

# Copy configuration files to their respective locations
cp ./configs/hyprland.conf ~/.config/hypr/hyprland.conf
cp ./configs/waybar_config.json ~/.config/waybar/config
cp ./configs/waybar_style.css ~/.config/waybar/style.css
cp ./configs/rofi_config.rasi ~/.config/rofi/config.rasi
cp ./configs/rofi_theme.rasi ~/.config/rofi/theme.rasi
cp ./configs/kitty.conf ~/.config/kitty/kitty.conf

# Output message for successful installation
echo "Setup completed. Configuration files have been copied."
echo "Please reboot to start using Hyprland with SDDM."
