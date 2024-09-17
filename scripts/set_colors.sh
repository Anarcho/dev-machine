#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Define paths
DOTFILES_DIR="$HOME/.dotfiles"  # Adjust this path to your dotfiles directory
COLOR_FILE="$DOTFILES_DIR/templates/colors.txt"
WAYBAR_STYLE_FILE="$HOME/.config/waybar/style.css"

# Function to read colors from the central color file
read_colors() {
    if [ ! -f "$COLOR_FILE" ]; then
        echo -e "$CER - Color file not found at $COLOR_FILE"
        exit 1
    fi

    declare -gA COLORS
    while IFS=': ' read -r key value; do
        COLORS[$key]=$value
    done < "$COLOR_FILE"
}

# Function to update Waybar colors
update_waybar_colors() {
    echo -e "$CNT - Updating Waybar colors..."
    
    if [ ! -f "$WAYBAR_STYLE_FILE" ]; then
        echo -e "$CER - Waybar style file not found at $WAYBAR_STYLE_FILE"
        return
    }
    
    # Create a temporary file
    TEMP_FILE=$(mktemp)
    
    # Read the Waybar style file and replace color variables
    while IFS= read -r line; do
        for key in "${!COLORS[@]}"; do
            line=${line//\$\{$key\}/${COLORS[$key]}}
        done
        echo "$line" >> "$TEMP_FILE"
    done < "$WAYBAR_STYLE_FILE"
    
    # Replace the original file with the modified one
    mv "$TEMP_FILE" "$WAYBAR_STYLE_FILE"
    
    echo -e "$COK - Waybar colors updated successfully."
}

# Main function to set colors for all configs
set_colors() {
    read_colors
    update_waybar_colors
    # Add more functions here for other configs in the future
    # For example:
    # update_alacritty_colors
    # update_rofi_colors
    # etc.
}

# Run the main function
set_colors

# Optionally, restart Waybar to apply changes
if command -v killall >/dev/null 2>&1; then
    echo -e "$CNT - Restarting Waybar..."
    killall waybar
    waybar &
    echo -e "$COK - Waybar restarted."
else
    echo -e "$CWR - Unable to restart Waybar automatically. Please restart it manually to see changes."
fi