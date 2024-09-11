#!/usr/bin/env bash

# Create necessary directories
mkdir -p ~/.hyprland_rice ~/.cache/hyprland_rice

# Initialize wallpaper daemon
swww-daemon -f xrgb &

# Set initial wallpaper
swww img ~/.config/hypr/themes/wallpapers/default_wallpaper.png -t none

# Start Waybar
~/.config/waybar/scripts/waybar_start.sh &

# Start network and bluetooth applets
nm-applet &
blueman-applet &

# Start session manager
lxsession &

# Start idle daemon
hypridle &

# Reload Hyprland configuration
sleep 2 && hyprctl reload &

# Load saved brightness
~/.config/hypr/scripts/load_brightness.sh &

# Final Hyprland reload
hyprctl reload