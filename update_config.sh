#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Default paths and URLs (as a fallback)
DEFAULT_DOTFILES_DIR="$HOME/.dotfiles"
DEFAULT_DOTFILES_REPO="https://github.com/anarcho/dotfiles.git"

# List of configurations to stow
configs=("hypr" "kitty" "waybar")

# Function to check and fix environment variables
check_env_var() {
    local var_name=$1
    local fallback_value=$2
    local var_value=${!var_name}

    if [ -z "$var_value" ]; then
        echo -e "$CWR - $var_name is not set. Attempting to set it to default value."
        export "$var_name"="$fallback_value"
        echo "export $var_name=\"$fallback_value\"" >> ~/.bashrc
        echo -e "$COK - $var_name set to $fallback_value."
    else
        echo -e "$CNT - $var_name is set to $var_value. Verifying..."
        if [[ "$var_name" == "DOTFILES_DIR" ]]; then
            if [ -d "$var_value" ]; then
                echo -e "$COK - $var_name path is valid."
            else
                echo -e "$CWR - $var_name directory does not exist. Creating it."
                mkdir -p "$var_value"
                if [ $? -eq 0 ]; then
                    echo -e "$COK - $var_name directory created."
                else
                    echo -e "$CER - Failed to create $var_name directory. Falling back to default."
                    export "$var_name"="$fallback_value"
                fi
            fi
        elif [[ "$var_name" == "DOTFILES_REPO" ]]; then
            if curl --output /dev/null --silent --head --fail "$var_value"; then
                echo -e "$COK - $var_name URL is reachable."
            else
                echo -e "$CER - $var_name URL is not reachable. Falling back to default."
                export "$var_name"="$fallback_value"
            fi
        fi
    fi
}

# Check and fix environment variables for DOTFILES_DIR and DOTFILES_REPO
check_env_var "DOTFILES_DIR" "$DEFAULT_DOTFILES_DIR"
check_env_var "DOTFILES_REPO" "$DEFAULT_DOTFILES_REPO"

# Clear the screen
clear

## Clone or update dotfiles
echo -e "$CNT - Setting up dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    echo -e "$CNT - Dotfiles directory already exists. Updating..."
    cd "$DOTFILES_DIR" && git pull || { echo -e "$CER - Failed to update dotfiles. Check your network connection."; exit 1; }
else
    echo -e "$CNT - Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || { echo -e "$CER - Failed to clone dotfiles. Check the repository URL or your network connection."; exit 1; }
fi

if [ $? -eq 0 ]; then
    echo -e "$COK - Dotfiles setup successful."
else
    echo -e "$CER - Failed to setup dotfiles. Exiting."
    exit 1
fi

# Clear symlinks

# Hypr
echo -e "$CNT - Clearing Hyprland symlinks..."
find "$HOME/.config/hypr" -maxdepth 1 -type l -delete

# Kitty
echo -e "$CNT - Clearing Kitty symlinks..."
find "$HOME/.config/kitty" -maxdepth 1 -type l -delete

# Waybar
echo -e "$CNT - Clearing Waybar symlinks..."
find "$HOME/.config/waybar" -maxdepth 1 -type l -delete

# Use Stow to manage dotfiles
echo -e "$CNT - Using stow to refresh dotfiles..."

cd "$DOTFILES_DIR" || { echo -e "$CER - Failed to change directory to $DOTFILES_DIR"; exit 1; }

# Iterate over the list of configs and stow them
for config in "${configs[@]}"; do
    echo -e "$CNT - Stowing $config..."
    stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
done

# Make the Hyprland autostart script executable (if it exists)
if [ -f "$HOME/.config/hypr/autostart.sh" ]; then
    chmod +x "$HOME/.config/hypr/autostart.sh"
    echo -e "$COK - Made Hyprland autostart script executable."
fi

# Make Waybar scripts executable
if [ -f "$HOME/.config/waybar/scripts/powermenu.sh" ]; then
    chmod +x "$HOME/.config/waybar/scripts/powermenu.sh"
    echo -e "$COK - Made Waybar powermenu script executable."
fi

echo -e "$CNT - Configuration update complete!"

# Prompt to restart Hyprland
read -rp $'[\e[1;33mACTION\e[0m] - Would you like to restart Hyprland to apply changes? (y/n) ' restart
if [[ $restart == "Y" || $restart == "y" ]]; then
    echo -e "$CNT - Restarting Hyprland..."
    hyprctl dispatch exit
else
    echo -e "$COK - Hyprland restart skipped. Please restart it manually if necessary."
fi