#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Log file for installation
LOG_FILE="$HOME/install.log"


if [ ! -f "$HOME/reset_repo.sh" ]; then
    echo "Copying reset_repo.sh to home directory..."
    cp "$(dirname "$0")/reset_repo.sh" "$HOME/reset_repo.sh"
    chmod +x "$HOME/reset_repo.sh"
    echo "reset_repo.sh has been copied to your home directory."
fi

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
            find "$dotfiles_wallpaper_dir" -maxdepth 1 -type f -name "*.jpg" -exec cp {} "$wallpaper_dir" \;
            if [ $? -eq 0 ]; then
                echo -e "$COK Wallpapers copied successfully."
            else
                echo -e "$CWR No jpg wallpapers found or error occurred during copy."
            fi
        else
            echo -e "$CER Wallpaper directory not found in dotfiles. Skipping wallpaper copy."
        fi

        [ $? -eq 0 ] && echo -e "$COK - Wallpaper directory copied successfully." || echo -e "$CER - Failed to copy wallpaper directory."
    else
        echo -e "$CWR - Wallpaper directory not found. Skipping."
    fi

    # Clearing old symlinks
    for config in "${CONFIGS[@]}"; do
        find "$HOME/.config/$config" -maxdepth 1 -type l -delete
    done

    # Handle Neovim configuration
    echo -e "$CNT - Setting up Neovim configuration..."
    if [ -d "$HOME/.config/nvim" ]; then
        read -rp $'[\e[1;33mACTION\e[0m] - Existing Neovim configuration found. Do you want to replace it? (y/n) ' replace_nvim_config
        case "$replace_nvim_config" in 
            y|Y )
                echo -e "$CNT - Backing up existing Neovim configuration..."
                mv "$HOME/.config/nvim" "$HOME/.config/nvim_backup_$(date +%Y%m%d%H%M%S)"
                echo -e "$COK - Existing Neovim configuration backed up."
                ;;
            n|N )
                echo -e "$CNT - Keeping existing Neovim configuration."
                ;;
            * )
                echo -e "$CER - Invalid choice. Keeping existing Neovim configuration."
                ;;
        esac
    fi

    if [ ! -d "$HOME/.config/nvim" ]; then
        echo -e "$CNT - Cloning kickstart.nvim config repository..."
        git clone https://github.com/Anarcho/kickstart.nvim.git "$HOME/.config/nvim"
        if [ $? -eq 0 ]; then
            echo -e "$COK - kickstart.nvim config repository cloned successfully."
            # Ensure the configuration is owned by the user
            chown -R $USER:$USER "$HOME/.config/nvim"
            
            # Initial setup for kickstart.nvim
            echo -e "$CNT - Running initial setup for kickstart.nvim..."
            nvim --headless -c 'quitall'
        else
            echo -e "$CER - Failed to clone kickstart.nvim config repository."
        fi

        echo -e "$COK - Neovim configuration setup completed."
    fi

    # Use stow to symlink the dotfiles
    cd "$DOTFILES_DIR"
    for config in "${CONFIGS[@]}"; do
        if [ "$config" != "nvim" ]; then  # Skip nvim as it's handled separately
            stow -R "$config" && echo -e "$COK - Successfully stowed $config." || echo -e "$CER - Failed to stow $config."
        fi
    done

    echo -e "$COK - All configuration files have been symlinked successfully."
    cd $HOME
}

run_scripts() {
    local repo_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    local scripts_dir="$repo_dir/scripts"
    echo -e "$CNT - Running additional scripts from $scripts_dir"

    if [ ! -d "$scripts_dir" ]; then
        echo -e "$CWR - Scripts directory not found. Skipping additional scripts."
        return
    fi

    for script in "$scripts_dir"/*; do
        if [ -f "$script" ]; then
            echo -e "$CNT - Processing script: $(basename "$script")"
            chmod +x "$script"
            if [ $? -eq 0 ]; then
                echo -e "$COK - Made $(basename "$script") executable."
                bash "$script"
                if [ $? -eq 0 ]; then
                    echo -e "$COK - Successfully ran $(basename "$script")"
                else
                    echo -e "$CER - Failed to run $(basename "$script")"
                fi
            else
                echo -e "$CER - Failed to make $(basename "$script") executable. Skipping."
            fi
        fi
    done

    echo -e "$COK - Finished running additional scripts."
}

reset_and_reinstall_configs() {
    echo -e "$CNT Starting Reset and Reinstall Configs process..."

    # Backup existing directories
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -d "$HOME/.dotfiles" ]; then
        echo -e "$CNT Backing up .dotfiles directory..."
        mv "$HOME/.dotfiles" "$HOME/.dotfiles_backup_$backup_timestamp"
        echo -e "$COK .dotfiles directory backed up."
    fi

    if [ -d "$HOME/.wallpapers" ]; then
        echo -e "$CNT Backing up .wallpapers directory..."
        mv "$HOME/.wallpapers" "$HOME/.wallpapers_backup_$backup_timestamp"
        echo -e "$COK .wallpapers directory backed up."
    fi

    # Remove existing directories
    echo -e "$CNT Removing existing .dotfiles and .wallpapers directories..."
    rm -rf "$HOME/.dotfiles" "$HOME/.wallpapers"
    echo -e "$COK Directories removed."

    # Clone dotfiles repository
    echo -e "$CNT Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$HOME/.dotfiles"
    if [ $? -ne 0 ]; then
        echo -e "$CER Failed to clone dotfiles repository. Exiting."
        exit 1
    fi
    echo -e "$COK Dotfiles repository cloned successfully."

    # Run setup_dotfiles function
    echo -e "$CNT Running setup_dotfiles function..."
    setup_dotfiles
    echo -e "$COK Config reset and reinstall process completed."
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
    echo -e "\nPlease select an option:"
    echo "1. Run All (Base Install + Additional Packages + Dotfiles + Scripts)"
    echo "2. Base Install (Nvidia + Core Packages)"
    echo "3. Install Additional Packages"
    echo "4. Setup Dotfiles"
    echo "5. Run Additional Scripts"
    echo "6. Reset and Reinstall Configs"
    echo "7. Fix Setup"
    echo "8. Exit"
    
    read -rp "Enter your choice [1-7]: " choice
    
    case $choice in
        1) base_install && install_additional_packages && setup_dotfiles && run_additional_scripts ;;
        2) base_install ;;
        3) install_additional_packages ;;
        4) setup_dotfiles ;;
        5) run_additional_scripts ;;
        6) reset_and_reinstall_configs ;;
        7) fix_setup ;;
        8) exit 0 ;;
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