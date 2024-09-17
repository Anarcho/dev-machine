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

# List of packages to install via pacman
pacman_packages=("wlroots" "xorg-xwayland" "polkit-kde-agent" "mkinitcpio" "qt5-wayland" "qt6-wayland" "grim" "slurp" "waybar" "swaylock" "brightnessctl" "hyprpaper" "kitty" "papirus-icon-theme" "noto-fonts-emoji" "neovim" "stow")

# List of packages to install via yay (AUR packages)
yay_packages=("hyprland")

# List of configs to stow
configs=("hypr" "kitty" "waybar")

# Function to prompt for stage
display_stage_prompt() {
    local stage_name="$1"
    echo -e "\n$CNT Stage: $stage_name"
    read -rp $'[\e[1;33mACTION\e[0m] - Do you want to proceed with this stage? (y/n) ' choice
    case "$choice" in 
        y|Y ) return 0;;
        n|N ) echo -e "$CWR Exiting script."; exit 1;;
        * ) echo -e "$CER Invalid choice. Exiting script."; exit 1;;
    esac
}

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

    # Final check and fallback
    var_value=${!var_name}
    if [ -z "$var_value" ]; then
        echo -e "$CER - Failed to set $var_name. Using hardcoded value."
        if [[ "$var_name" == "DOTFILES_DIR" ]]; then
            export "$var_name"="$HOME/.dotfiles"
        elif [[ "$var_name" == "DOTFILES_REPO" ]]; then
            export "$var_name"="https://github.com/anarcho/dotfiles.git"
        fi
    fi
}

# Clear the screen
clear

# Stage 1: Initial Setup and Environment Check
display_stage_prompt "Initial Setup and Environment Check"

echo -e "$CNT - Checking for NVIDIA GPU..."
if lspci | grep -i nvidia &>/dev/null; then
    ISNVIDIA=true
    echo -e "$CNT - NVIDIA GPU detected."
else
    ISNVIDIA=false
    echo -e "$CNT - NVIDIA GPU not detected."
fi

echo -e "$CNT - Checking if system is a VM..."
ISVM=$(systemd-detect-virt)
if [[ $ISVM != "none" ]]; then
    echo -e "$CWR - Running in a VM."
    ISVM=true
else
    ISVM=false
fi

check_env_var "DOTFILES_DIR" "$DEFAULT_DOTFILES_DIR"
check_env_var "DOTFILES_REPO" "$DEFAULT_DOTFILES_REPO"

# Stage 2: NVIDIA Setup (if applicable)
if [[ "$ISNVIDIA" == true && "$ISVM" == false ]]; then
    display_stage_prompt "NVIDIA Setup"

    echo -e "$CNT - Setting up NVIDIA using nvidia-all..."

    # Remove potentially conflicting NVIDIA packages
    echo -e "$CNT - Removing potentially conflicting NVIDIA packages..."
    yes | sudo pacman -Rdd nvidia nvidia-utils nvidia-settings 2>/dev/null

    # Clone nvidia-all repository
    echo -e "$CNT - Cloning nvidia-all repository..."
    git clone https://github.com/Frogging-Family/nvidia-all.git $HOME/setup-repos/nvidia-all &>> "$LOG_FILE"
    cd $HOME/setup-repos/nvidia-all || { echo -e "$CER - Failed to change to nvidia-all directory. Exiting."; exit 1; }

    # Install nvidia-all
    echo -e "$CNT - Installing nvidia-all..."
    echo -e "$CWR - You will now see prompts from the nvidia-all installer. Please respond to them as needed."
    makepkg -si

    if [ $? -eq 0 ]; then
        echo -e "$COK - nvidia-all installed successfully."
    else
        echo -e "$CER - Failed to install nvidia-all. Please check the output above for any errors."
        exit 1
    fi

    cd $HOME

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

# Stage 3: Package Installation (Pacman)
display_stage_prompt "Package Installation (Pacman)"

# Function to install software using pacman
install_pacman_package() {
    check_env_var "DOTFILES_DIR" "$DEFAULT_DOTFILES_DIR"
    check_env_var "DOTFILES_REPO" "$DEFAULT_DOTFILES_REPO"
    
    if pacman -Qi $1 &>/dev/null; then
        echo -e "$COK - $1 is already installed."
    else
        echo -e "$CNT - Installing $1 using pacman..."
        sudo pacman -S --noconfirm $1 &>> "$LOG_FILE"
        if pacman -Qi $1 &>/dev/null; then
            echo -e "$COK - $1 was installed successfully."
        else
            echo -e "$CER - Failed to install $1. Check install.log."
            exit 1
        fi
    fi
}

echo -e "$CNT - Installing packages using pacman..."
for pkg in "${pacman_packages[@]}"; do
    install_pacman_package $pkg
done

# Stage 4: AUR Helper Installation
display_stage_prompt "AUR Helper Installation"

# Ensure yay is installed
if ! command -v yay &> /dev/null; then
    echo -e "$CWR - Yay is not installed. Installing yay..."
    git clone https://aur.archlinux.org/yay.git $HOME/setup-repos/yay &>> "$LOG_FILE"
    cd $HOME/setup-repos/yay && makepkg -si --noconfirm &>> "$LOG_FILE"
    cd $HOME
    if command -v yay &> /dev/null; then
        echo -e "$COK - Yay installed successfully."
    else
        echo -e "$CER - Failed to install yay. Exiting."
        exit 1
    fi
else
    echo -e "$COK - Yay is already installed."
fi

# Stage 5: AUR Package Installation
display_stage_prompt "AUR Package Installation"

# Function to install software using yay
install_yay_package() {
    check_env_var "DOTFILES_DIR" "$DEFAULT_DOTFILES_DIR"
    check_env_var "DOTFILES_REPO" "$DEFAULT_DOTFILES_REPO"
    
    if yay -Qi $1 &>/dev/null; then
        echo -e "$COK - $1 is already installed."
    else
        echo -e "$CNT - Installing $1 using yay..."
        yay -S --noconfirm $1 &>> "$LOG_FILE"
        if yay -Qi $1 &>/dev/null; then
            echo -e "$COK - $1 was installed successfully."
        else
            echo -e "$CER - Failed to install $1. Check install.log."
            exit 1
        fi
    fi
}

echo -e "$CNT - Installing packages using yay..."
for pkg in "${yay_packages[@]}"; do
    install_yay_package $pkg
done

# Stage 6: Dotfiles Setup
display_stage_prompt "Dotfiles Setup"

check_env_var "DOTFILES_DIR" "$DEFAULT_DOTFILES_DIR"
check_env_var "DOTFILES_REPO" "$DEFAULT_DOTFILES_REPO"

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

cd $HOME

# Copy wallpaper directory
echo -e "$CNT - Copying wallpaper directory..."
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    cp -r "$DOTFILES_DIR/wallpapers" "$HOME/.wallpapers"
    if [ $? -eq 0 ]; then
        echo -e "$COK - Wallpaper directory copied successfully."
    else
        echo -e "$CER - Failed to copy wallpaper directory."
    fi
else
    echo -e "$CWR - Wallpaper directory not found. Skipping."
fi

# Stage 7: Configuration Files Setup
display_stage_prompt "Configuration Files Setup"

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

cd $HOME

# Stage 8: Final Cleanup and Reboot
display_stage_prompt "Final Cleanup and Reboot"

# Remove the setup-repos directory
echo -e "$CNT - Cleaning up: Removing setup-repos directory..."
rm -rf "$HOME/setup-repos"
if [ $? -eq 0 ]; then
    echo -e "$COK - setup-repos directory removed successfully."
else
    echo -e "$CWR - Failed to remove setup-repos directory. You may want to remove it manually from $HOME/setup-repos"
fi

# Prompt for reboot
read -rp $'[\e[1;33mACTION\e[0m] - Do you want to reboot now? (y/n) ' reboot_choice
case "$reboot_choice" in 
    y|Y ) echo "Rebooting..."; sudo reboot;;
    n|N ) echo "Reboot skipped. Please remember to reboot your system to apply all changes.";;
    * ) echo "Invalid choice. Please reboot manually when convenient.";;
esac

echo -e "$COK - Setup completed successfully."