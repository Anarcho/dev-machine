#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Source the config file to get DOTFILES_DIR
source "$(dirname "$0")/../setup_config.conf"

# Create .wallpapers directory if it doesn't exist
wallpaper_dir="$HOME/.wallpapers"
if [ ! -d "$wallpaper_dir" ]; then
    echo -e "$CNT Creating wallpaper directory at $wallpaper_dir"
    mkdir -p "$wallpaper_dir"
    if [ $? -eq 0 ]; then
        echo -e "$COK Wallpaper directory created successfully."
    else
        echo -e "$CER Failed to create wallpaper directory. Exiting."
        exit 1
    fi
else
    echo -e "$CNT Wallpaper directory already exists at $wallpaper_dir"
fi

# Copy wallpapers from dotfiles
dotfiles_wallpaper_dir="$DOTFILES_DIR/wallpapers"
if [ -d "$dotfiles_wallpaper_dir" ]; then
    echo -e "$CNT Copying wallpapers from $dotfiles_wallpaper_dir to $wallpaper_dir"
    cp "$dotfiles_wallpaper_dir"/*.jpg "$wallpaper_dir" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "$COK Wallpapers copied successfully."
    else
        echo -e "$CWR No jpg wallpapers found or error occurred during copy."
    fi
else
    echo -e "$CER Wallpaper directory not found in dotfiles. Skipping wallpaper copy."
fi

# List copied wallpapers
echo -e "$CNT Wallpapers in $wallpaper_dir:"
ls -1 "$wallpaper_dir"