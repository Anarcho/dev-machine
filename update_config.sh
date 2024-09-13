#!/bin/bash

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Set the location for your dotfiles
DOTFILES_DIR="$HOME/.dotfiles"

# URL of your dotfiles repository
DOTFILES_REPO="https://github.com/anarcho/dotfiles.git"

# List of configurations to stow
configs=("hypr Kitty waybar")

# Function to check if variable is already in .bashrc
add_to_bashrc() {
    VAR_NAME=$1
    VAR_VALUE=$2

    # Check if the variable is already set in .bashrc
    if grep -q "^export $VAR_NAME=" ~/.bashrc; then
        echo -e "$CWR - $VAR_NAME is already set in ~/.bashrc. Updating its value."
        sed -i "s|^export $VAR_NAME=.*|export $VAR_NAME=\"$VAR_VALUE\"|" ~/.bashrc
    else
        echo -e "$CNT - Adding $VAR_NAME to ~/.bashrc."
        echo "export $VAR_NAME=\"$VAR_VALUE\"" >> ~/.bashrc
    fi
}

# Add DOTFILES_DIR and DOTFILES_REPO to ~/.bashrc
add_to_bashrc "DOTFILES_DIR" "$DOTFILES_DIR"
add_to_bashrc "DOTFILES_REPO" "$DOTFILES_REPO"

# Let the user know they need to source .bashrc or restart terminal
echo -e "$COK - Added variables to ~/.bashrc. Please run 'source ~/.bashrc' or restart your terminal to apply the changes."

## Clone or update dotfiles
echo -e "$CNT - Setting up dotfiles..."
if [ -d "~/.dotfiles" ]; then
    echo -e "$CNT - Dotfiles directory already exists. Updating..."
    cd "~/.dotfiles" && git pull
else
    echo -e "$CNT - Cloning dotfiles repository..."
    git clone "https://github.com/anarcho/dotfiles.git" "~/.dotfiles"
fi

if [ $? -eq 0 ]; then
    echo -e "$COK - Dotfiles setup successful."
else
    echo -e "$CER - Failed to setup dotfiles. Exiting."
    exit 1
fi

# clear symlinks

# Hypr
echo -e "$CNT - Clearing Hyprland symlinks..."
find "$HOME/.config/hypr" -maxdepth 1 -type l -delete

# kitty
echo -e "$CNT - Clearing kitty symlinks..."
find "$HOME/.config/kitty" -maxdepth 1 -type l -delete

# waybar
echo -e "$CNT - Clearing waybar symlinks..."
find "$HOME/.config/waybar" -maxdepth 1 -type l -delete


# Use Stow to manage dotfiles
echo -e "$CNT - Using stow to refresh dotfiles..."

cd "~/.dotfiles" || { echo -e "$CER - Failed to change directory to ~/.dotfiles"; exit 1; }

# Iterate over the list of configs and stow them
for config in "${configs[@]}"; do
    echo -e "$CNT - Stowing $config..."
    stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
done

# Make the Hyprland autostart script executable (if it exists)
if [ -f "$HOME/.config/hypr/autostart.sh" ]; then
    chmod +x "$HOME/.config/hypr/autostart.sh"
    echo -e "$COK Made Hyprland autostart script executable."
fi

# Make way bar scripts executable

if [ -f "$HOME/.config/waybar/scripts/powermenu.sh" ]; then
    chmod +x "$HOME/.config/waybar/scripts/powermenu.sh"
    echo -e "$COK Made waybar battery script executable."
fi

echo -e "$CNT Configuration update complete!"

# Prompt to restart Hyprland
read -rp $'[\e[1;33mACTION\e[0m] - Would you like to restart Hyprland to apply changes? (y/n) ' restart
if [[ $restart == "Y" || $restart == "y" ]]; then
    echo -e "$CNT Restarting Hyprland..."
    hyprctl dispatch exit
else
    echo -e "$COK Hyprland restart skipped. Please restart it manually if necessary."
fi
