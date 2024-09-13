#!/bin/bash

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Default paths and URLs (as a fallback)
DEFAULT_DOTFILES_DIR="$HOME/.dotfiles"
DEFAULT_DOTFILES_REPO="https://github.com/anarcho/dotfiles.git"

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
        # Verify if directory exists for DOTFILES_DIR, or if URL is reachable for DOTFILES_REPO
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

# Source .bashrc to make sure environment variables are loaded
source ~/.bashrc

# Let the user know they need to source .bashrc or restart terminal
echo -e "$COK - Added/Updated environment variables to ~/.bashrc. Please run 'source ~/.bashrc' or restart your terminal to apply the changes."

# Clear the screen
clear

# Clone or update dotfiles
echo -e "$CNT - Setting up dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    echo -e "$CNT - Dotfiles directory already exists. Updating..."
    cd "$DOTFILES_DIR" && git pull
else
    echo -e "$CNT - Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

if [ $? -eq 0 ]; then
    echo -e "$COK - Dotfiles setup successful."
else
    echo -e "$CER - Failed to setup dotfiles. Exiting."
    exit 1
fi

# List of configurations to stow
configs=("hypr" "kitty" "waybar")

# Let the user know they need to source .bashrc or restart terminal
echo -e "$COK - Added variables to ~/.bashrc. Please run 'source ~/.bashrc' or restart your terminal to apply the changes."

# clear the screen
clear

# Function to check if a directory exists and clear symlinks
clear_symlinks() {
    local dir=$1
    if [ -d "$dir" ]; then
        echo -e "$CNT - Clearing symlinks in $dir..."
        find "$dir" -maxdepth 1 -type l -delete
    else
        echo -e "$CWR - Directory $dir not found. Skipping symlink clearing."
    fi
}

# Check for NVIDIA GPU
if lspci | grep -i nvidia &>/dev/null; then
    ISNVIDIA=true
    echo -e "$CNT - NVIDIA GPU detected."
else
    ISNVIDIA=false
    echo -e "$CNT - NVIDIA GPU not detected."
fi

# Check if the machine is a VM
echo -e "$CNT - Checking for Physical or VM..."
ISVM=$(hostnamectl | grep Chassis)
if [[ $ISVM == *"vm"* ]]; then
    ISVM=true
    echo -e "$CWR - VM detected. Some operations may not be supported."
else
    ISVM=false
fi

# Ensure sudo is needed
echo -e "$CNT - This script will require sudo permissions."
sleep 1

# Install software function
install_software() {
    if yay -Q $1 &>/dev/null; then
        echo -e "$COK - $1 is already installed."
    else
        echo -e "$CNT - Installing $1 ..."
        yes | yay -S --noconfirm $1 &>> $INSTLOG
        if yay -Q $1 &>/dev/null; then
            echo -e "$COK - $1 was installed."
        else
            echo -e "$CER - Failed to install $1. Please check install.log"
            exit 1
        fi
    fi
}

# NVIDIA setup (if not in VM)
if [ "$ISNVIDIA" = true ] && [ "$ISVM" = false ]; then
    echo -e "$CNT - Nvidia setup..."
    for pkg in linux-headers nvidia nvidia-utils nvidia-settings lib32-nvidia-utils qt5-wayland qt5ct; do
        install_software $pkg
    done

    # Nvidia configuration
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio --generate /boot/initramfs-linux.img
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    sudo tee -a /etc/environment <<EOF
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
EOF
else
    if [ "$ISVM" = true ]; then
        echo -e "$CNT - VM detected. Skipping NVIDIA setup."
    else
        echo -e "$CNT - No NVIDIA GPU detected. Skipping NVIDIA setup."
    fi
fi

# Install main components
echo -e "$CNT - Installing main components..."
for pkg in hyprland kitty neovim stow waybar; do
    install_software $pkg
done

# Clone or update dotfiles
echo -e "$CNT - Setting up dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    echo -e "$CNT - Dotfiles directory already exists. Updating..."
    cd "$DOTFILES_DIR" && git pull
else
    echo -e "$CNT - Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

if [ $? -eq 0 ]; then
    echo -e "$COK - Dotfiles setup successful."
else
    echo -e "$CER - Failed to setup dotfiles. Exiting."
    exit 1
fi

# Clear old symlinks
clear_symlinks "$HOME/.config/hypr"
clear_symlinks "$HOME/.config/kitty"
clear_symlinks "$HOME/.config/waybar"

# Use stow to manage dotfiles
echo -e "$CNT - Using stow to refresh dotfiles..."
cd "$DOTFILES_DIR" || { echo -e "$CER - Failed to change directory to $DOTFILES_DIR"; exit 1; }

for config in "${configs[@]}"; do
    echo -e "$CNT - Stowing $config..."
    stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
done

# Make scripts executable
chmod +x "$HOME/.config/waybar/scripts/powermenu.sh" 2>/dev/null

echo -e "$CNT - Configuration update complete!"

# Prompt to restart Hyprland
read -rp $'[\e[1;33mACTION\e[0m] - Would you like to restart Hyprland to apply changes? (y/n) ' restart
if [[ $restart == "Y" || $restart == "y" ]]; then
    echo -e "$CNT Restarting Hyprland..."
    hyprctl dispatch exit
else
    echo -e "$COK Hyprland restart skipped. Please restart it manually if necessary."
fi
