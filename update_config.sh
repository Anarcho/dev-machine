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

# Update dotfiles
echo -e "$CNT Updating dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    cd "$DOTFILES_DIR" && git pull
    if [ $? -eq 0 ]; then
        echo -e "$COK Dotfiles updated successfully."
    else
        echo -e "$CER Failed to update dotfiles. Please check your internet connection or repository status."
        exit 1
    fi
else
    echo -e "$CER Dotfiles directory not found. Please run the setup script first."
    exit 1
fi

# Function to update symlinks
update_symlink() {
    local source="$1"
    local target="$2"

    # Check if the target file already exists
    if [ -e "$target" ]; then
        echo -e "$CWR - $target already exists. Removing it before creating the symlink."
        rm -f "$target"
    fi

    # Create the symlink
    ln -sf "$source" "$target" && echo -e "$COK Updated symlink for $target" || echo -e "$CER Failed to update symlink for $target"
}

# Ensure configuration directories exist
mkdir -p "$HOME/.config/hypr" "$HOME/.config/kitty" "$HOME/.config/nvim"

# Update configuration symlinks
echo -e "$CNT Updating configuration symlinks..."

# Hyprland
update_symlink "$DOTFILES_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"

# Kitty
update_symlink "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# Neovim
update_symlink "$DOTFILES_DIR/nvim/init.vim" "$HOME/.config/nvim/init.vim"

# Make the Hyprland autostart script executable (if it exists)
if [ -f "$HOME/.config/hypr/autostart.sh" ]; then
    chmod +x "$HOME/.config/hypr/autostart.sh"
    echo -e "$COK Made Hyprland autostart script executable."
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
