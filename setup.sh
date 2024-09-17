#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Log file for installation
LOG_FILE="$HOME/install.log"

# Source configuration file
source ./setup_config.conf

# Function definitions
check_nvidia_and_vm() {
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
}

base_install() {
    check_nvidia_and_vm

    if [[ "$ISNVIDIA" == true && "$ISVM" == false ]]; then
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
    else
        echo -e "$CNT - Skipping NVIDIA setup."
    fi

    # Install base packages
    echo -e "$CNT - Installing base packages..."
    for pkg in "${BASE_PACKAGES[@]}"; do
        sudo pacman -S --noconfirm $pkg
        [ $? -eq 0 ] && echo -e "$COK - $pkg installed successfully." || echo -e "$CER - Failed to install $pkg."
    done

    # Install yay if not present
    if ! command -v yay &> /dev/null; then
        echo -e "$CWR - Yay is not installed. Installing yay..."
        git clone https://aur.archlinux.org/yay.git $HOME/setup-repos/yay &>> "$LOG_FILE"
        cd $HOME/setup-repos/yay && makepkg -si --noconfirm &>> "$LOG_FILE"
        cd $HOME
        [ $? -eq 0 ] && echo -e "$COK - Yay installed successfully." || { echo -e "$CER - Failed to install yay. Exiting."; exit 1; }
    else
        echo -e "$COK - Yay is already installed."
    fi

    # Install Hyprland
    echo -e "$CNT - Installing Hyprland..."
    yay -S --noconfirm hyprland
    [ $? -eq 0 ] && echo -e "$COK - Hyprland installed successfully." || echo -e "$CER - Failed to install Hyprland."

    # Configure mkinitcpio
    echo -e "$CNT - Configuring mkinitcpio..."
    sudo sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    [ $? -eq 0 ] && echo -e "$COK - mkinitcpio configured successfully." || echo -e "$CER - Failed to configure mkinitcpio."

    # Add NVIDIA modprobe configuration
    echo -e "$CNT - Adding NVIDIA modprobe configuration..."
    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    [ $? -eq 0 ] && echo -e "$COK - NVIDIA modprobe configuration added successfully." || echo -e "$CER - Failed to add NVIDIA modprobe configuration."

    # Set environment variables
    echo -e "$CNT - Setting NVIDIA and Wayland environment variables..."
    sudo tee -a /etc/environment << EOF
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_RENDERER=vulkan
EOF
    [ $? -eq 0 ] && echo -e "$COK - Environment variables set successfully." || echo -e "$CER - Failed to set environment variables."
}

install_additional_packages() {
    echo -e "$CNT - Installing additional packages..."
    
    for pkg in "${ADDITIONAL_PACMAN_PACKAGES[@]}"; do
        sudo pacman -S --noconfirm $pkg
        [ $? -eq 0 ] && echo -e "$COK - $pkg installed successfully." || echo -e "$CER - Failed to install $pkg."
    done

    for pkg in "${ADDITIONAL_YAY_PACKAGES[@]}"; do
        yay -S --noconfirm $pkg
        [ $? -eq 0 ] && echo -e "$COK - $pkg installed successfully." || echo -e "$CER - Failed to install $pkg."
    done

    echo -e "$CNT - Creating config directories..."
    for config in "${CONFIGS[@]}"; do
        mkdir -p "$HOME/.config/$config"
        [ $? -eq 0 ] && echo -e "$COK - Created $HOME/.config/$config" || echo -e "$CER - Failed to create $HOME/.config/$config"
    done
}

setup_dotfiles() {
    echo -e "$CNT - Setting up dotfiles..."
    
    if [ -d "$DOTFILES_DIR" ]; then
        echo -e "$CNT - Dotfiles directory exists. Pulling updates..."
        cd "$DOTFILES_DIR" && git pull
    else
        echo -e "$CNT - Cloning dotfiles repository..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi

    [ $? -eq 0 ] && echo -e "$COK - Dotfiles setup successful." || { echo -e "$CER - Failed to setup dotfiles. Exiting."; exit 1; }

    cd $HOME

    # Copy wallpaper directory
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        cp -r "$DOTFILES_DIR/wallpapers" "$HOME/.wallpapers"
        [ $? -eq 0 ] && echo -e "$COK - Wallpaper directory copied successfully." || echo -e "$CER - Failed to copy wallpaper directory."
    else
        echo -e "$CWR - Wallpaper directory not found. Skipping."
    fi

    # Clearing old symlinks
    for config in "${CONFIGS[@]}"; do
        find "$HOME/.config/$config" -maxdepth 1 -type l -delete
    done

    # Use stow to symlink the dotfiles
    cd "$DOTFILES_DIR"
    for config in "${CONFIGS[@]}"; do
        stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
    done

    echo -e "$COK - Configuration files have been symlinked successfully."
    cd $HOME
}

fix_setup() {
    echo -e "$CNT - Starting Fix Setup..."
    
    # Backup existing configs
    for config in "${CONFIGS[@]}"; do
        if [ -d "$HOME/.config/$config" ]; then
            mv "$HOME/.config/$config" "$HOME/.config/${config}_backup_$(date +%Y%m%d%H%M%S)"
            echo -e "$COK - Backed up $config configuration."
        fi
    done

    # Remove dotfiles directory
    [ -d "$DOTFILES_DIR" ] && rm -rf "$DOTFILES_DIR" && echo -e "$COK - Removed existing dotfiles directory."

    # Rerun all steps
    base_install
    install_additional_packages
    setup_dotfiles

    echo -e "$COK - Fix Setup completed."
}

# Main menu function
main_menu() {
    echo -e "\nPlease select a stage to run:"
    echo "1. All (Base Install + Additional Packages + Dotfiles)"
    echo "2. Base Install (Nvidia + Core Packages)"
    echo "3. Additional Packages Install"
    echo "4. Dotfiles Setup"
    echo "5. Fix Setup"
    echo "6. Exit"
    
    read -rp "Enter your choice [1-6]: " choice
    
    case $choice in
        1) base_install && install_additional_packages && setup_dotfiles ;;
        2) base_install ;;
        3) install_additional_packages ;;
        4) setup_dotfiles ;;
        5) fix_setup ;;
        6) exit 0 ;;
        *) echo -e "$CER Invalid choice. Please try again."; main_menu ;;
    esac

    # Cleanup and reboot prompt
    echo -e "$CNT - Cleaning up: Removing setup-repos directory..."
    rm -rf "$HOME/setup-repos"
    [ $? -eq 0 ] && echo -e "$COK - setup-repos directory removed successfully." || echo -e "$CWR - Failed to remove setup-repos directory. You may want to remove it manually from $HOME/setup-repos"

    read -rp $'[\e[1;33mACTION\e[0m] - Do you want to reboot now? (y/n) ' reboot_choice
    case "$reboot_choice" in 
        y|Y ) echo "Rebooting..."; sudo reboot;;
        n|N ) echo "Reboot skipped. Please remember to reboot your system to apply all changes.";;
        * ) echo "Invalid choice. Please reboot manually when convenient.";;
    esac
}

# Main execution
clear
echo -e "$CNT Starting setup script..."
main_menu
echo -e "$COK Setup script completed successfully."