#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Default paths and URLs (as a fallback)
DEFAULT_DOTFILES_DIR="$HOME/.dotfiles"
DEFAULT_DOTFILES_REPO="https://github.com/anarcho/dotfiles.git"

# Log file for installation
LOG_FILE="$HOME/install.log"

# List of packages to install
required_software=("wayland" "xorg-xwayland" "qt5-wayland" "qt6-wayland" "wl-clipboard" "grim" "slurp" "hyprland" "kitty" "waybar" "neovim" "stow")

# List of configs to stow
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

# NVIDIA check and VM check
echo -e "$CNT - Checking for NVIDIA GPU..."
if lspci | grep -i nvidia &>/dev/null; then
    ISNVIDIA=true
    echo -e "$CNT - NVIDIA GPU detected."
else
    ISNVIDIA=false
    echo -e "$CNT - NVIDIA GPU not detected."
fi

echo -e "$CNT - Checking if system is a VM..."
ISVM=$(hostnamectl | grep Chassis | grep -o 'vm')
if [[ $ISVM == "vm" ]]; then
    echo -e "$CWR - Running in a VM."
    ISVM=true
else
    ISVM=false
fi

# Ensure yay is installed
if ! command -v yay &> /dev/null; then
    echo -e "$CWR - Yay is not installed."
    read -rp $'[\e[1;33mACTION\e[0m] - Would you like to install yay? (y/n) ' INSTYAY
    if [[ $INSTYAY =~ [Yy] ]]; then
        git clone https://aur.archlinux.org/yay.git &>> "$LOG_FILE"
        cd yay && makepkg -si --noconfirm &>> ../"$LOG_FILE" && cd ..
        echo -e "$COK - Yay installed."
    else
        echo -e "$CER - Yay is required. Exiting."
        exit 1
    fi
fi

# Function to install software
install_software() {
    if yay -Q $1 &>/dev/null; then
        echo -e "$COK - $1 is already installed."
    else
        echo -e "$CNT - Installing $1 ..."
        yes | yay -S --noconfirm $1 &>> "$LOG_FILE"
        if yay -Q $1 &>/dev/null; then
            echo -e "$COK - $1 was installed successfully."
        else
            echo -e "$CER - Failed to install $1. Check install.log."
            exit 1
        fi
    fi
}

# NVIDIA setup (if not a VM and NVIDIA detected)
if [[ "$ISNVIDIA" == true && "$ISVM" == false ]]; then
    echo -e "$CNT - Setting up NVIDIA using nvidia-all..."

    # Remove potentially conflicting NVIDIA packages
    echo -e "$CNT - Removing potentially conflicting NVIDIA packages..."
    #yes | sudo pacman -Rdd nvidia nvidia-utils nvidia-settings 2>/dev/null

    # Clone nvidia-all repository
    echo -e "$CNT - Cloning nvidia-all repository..."
    git clone https://github.com/Frogging-Family/nvidia-all.git &>> "$LOG_FILE"
    cd nvidia-all || { echo -e "$CER - Failed to change to nvidia-all directory. Exiting."; exit 1; }

    # Install nvidia-all
    echo -e "$CNT - Installing nvidia-all..."
    makepkg -si --noconfirm &>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        echo -e "$COK - nvidia-all installed successfully."
    else
        echo -e "$CER - Failed to install nvidia-all. Check install.log."
        exit 1
    fi

    cd ..

    # Add NVIDIA modprobe configuration
    echo -e "$CNT - Adding NVIDIA modprobe configuration..."
    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "$COK - NVIDIA modprobe configuration added successfully."
    else
        echo -e "$CER - Failed to add NVIDIA modprobe configuration."
    fi

    # Set environment variables for NVIDIA and Wayland
    echo -e "$CNT - Setting NVIDIA and Wayland environment variables..."
    sudo tee -a /etc/environment << EOF
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_RENDERER=vulkan
EOF
    if [ $? -eq 0 ]; then
        echo -e "$COK - Environment variables set successfully."
    else
        echo -e "$CER - Failed to set environment variables."
    fi
else
    echo -e "$CNT - Skipping NVIDIA setup."
fi


# Clone or update dotfiles
echo -e "$CNT - Setting up dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    echo -e "$CNT - Dotfiles directory exists. Pulling updates..."
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

# Install required software after NVIDIA setup
echo -e "$CNT - Installing additional packages..."
for pkg in "${required_software[@]}"; do
    install_software $pkg
done

# Clearing old symlinks
clear_symlinks() {
    local dir=$1
    if [ -d "$dir" ]; then
        echo -e "$CNT - Clearing symlinks in $dir..."
        find "$dir" -maxdepth 1 -type l -delete
    else
        echo -e "$CWR - Directory $dir not found. Skipping."
    fi
}
clear_symlinks "$HOME/.config/hypr"
clear_symlinks "$HOME/.config/kitty"
clear_symlinks "$HOME/.config/waybar"

# Use stow to symlink the dotfiles
echo -e "$CNT - Using stow to symlink dotfiles..."
cd "$DOTFILES_DIR" || { echo -e "$CER - Failed to change to $DOTFILES_DIR. Exiting."; exit 1; }

for config in "${configs[@]}"; do
    stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
done

echo -e "$COK - Configuration files have been symlinked successfully."

echo -e "$CNT - Cleaning up: Removing nvidia-all repository..."
rm -rf "$HOME/nvidia-all"
if [ $? -eq 0 ]; then
    echo -e "$COK - nvidia-all repository removed successfully."
else
    echo -e "$CWR - Failed to remove nvidia-all repository. You may want to remove it manually from $HOME/nvidia-all"
fi

echo -e "$COK - Setup completed successfully."