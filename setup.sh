#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Log file for installation
LOG_FILE="$HOME/install.log"

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Configuration file
CONFIG_FILE="$SCRIPT_DIR/setup_config.conf"

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    if [ $exit_code -ne 0 ]; then
        echo -e "$CER $error_message" | tee -a "$LOG_FILE"
        exit $exit_code
    fi
}

# Logging function
log_message() {
    local message=$1
    echo -e "$message" | tee -a "$LOG_FILE"
}

# User confirmation function
confirm_action() {
    local message=$1
    read -rp "$message (y/n) " choice
    case "$choice" in 
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo -e "$CER Invalid choice."; return 1;;
    esac
}

# Backup function
create_backup() {
    local dir_to_backup=$1
    local backup_name="$dir_to_backup.bak.$(date +%Y%m%d%H%M%S)"
    if [ -d "$dir_to_backup" ]; then
        cp -r "$dir_to_backup" "$backup_name"
        log_message "$COK Backup created: $backup_name"
    else
        log_message "$CWR Directory $dir_to_backup does not exist. Skipping backup."
    fi
}

# Check and install dependencies
check_dependencies() {
    local deps=("git" "stow" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            log_message "$CWR $dep is not installed. Installing..."
            sudo pacman -S --noconfirm $dep
            handle_error $? "Failed to install $dep"
        fi
    done
    log_message "$COK All dependencies are installed."
}

# Source configuration file
source_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "$COK Configuration file sourced from $CONFIG_FILE"
    else
        log_message "$CER Configuration file not found at $CONFIG_FILE. Exiting."
        exit 1
    fi
}

# Nvidia Driver Install function
nvidia_install() {
    log_message "$CNT Starting Nvidia Driver Installation..."
    
    # Clone nvidia-all repository
    git clone https://github.com/Frogging-Family/nvidia-all.git $HOME/setup-repos/nvidia-all
    handle_error $? "Failed to clone nvidia-all repository"
    
    # Install nvidia-all
    cd $HOME/setup-repos/nvidia-all
    makepkg -si --noconfirm
    handle_error $? "Failed to install nvidia-all"
    
    # Remove cloned repository
    cd $HOME
    rm -rf $HOME/setup-repos/nvidia-all
    
    log_message "$COK Nvidia Driver Installation completed."
}

# Package Install function
package_install() {
    log_message "$CNT Starting Package Installation..."
    
    # Check and install yay if not present
    if ! command -v yay &> /dev/null; then
        log_message "$CWR yay is not installed. Installing..."
        git clone https://aur.archlinux.org/yay.git $HOME/setup-repos/yay
        cd $HOME/setup-repos/yay
        makepkg -si --noconfirm
        handle_error $? "Failed to install yay"
        cd $HOME
        rm -rf $HOME/setup-repos/yay
    fi
    
    # Install pacman packages
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        sudo pacman -S --noconfirm $pkg
        handle_error $? "Failed to install $pkg"
    done
    
    # Install yay packages
    for pkg in "${YAY_PACKAGES[@]}"; do
        yay -S --noconfirm $pkg
        handle_error $? "Failed to install $pkg"
    done
    
    log_message "$COK Package Installation completed."
}

# Dotfiles Setup function
dotfiles_setup() {
    log_message "$CNT Starting Dotfiles Setup..."
    
    if [ -d "$DOTFILES_DIR" ]; then
        cd "$DOTFILES_DIR"
        git fetch
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})
        
        if [ $LOCAL != $REMOTE ]; then
            log_message "$CNT Updates available. Pulling changes..."
            git pull
            handle_error $? "Failed to pull dotfiles updates"
        else
            log_message "$COK Dotfiles are up to date."
        fi
    else
        log_message "$CNT Cloning dotfiles repository..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        handle_error $? "Failed to clone dotfiles repository"
    fi
    
    # Clear existing symlinks
    for config in "${CONFIGS[@]}"; do
        find "$HOME/.config/$config" -type l -delete
    done
    
    # Stow dotfiles
    cd "$DOTFILES_DIR"
    for config in "${CONFIGS[@]}"; do
        stow -R "$config"
        handle_error $? "Failed to stow $config"
    done
    
    log_message "$COK Dotfiles Setup completed."
}

# Fix Setup function
fix_setup() {
    log_message "$CNT Starting Fix Setup..."
    
    # Reinstall yay
    log_message "$CNT Reinstalling yay..."
    rm -rf $HOME/setup-repos/yay
    git clone https://aur.archlinux.org/yay.git $HOME/setup-repos/yay
    cd $HOME/setup-repos/yay
    makepkg -si --noconfirm
    handle_error $? "Failed to reinstall yay"
    cd $HOME
    rm -rf $HOME/setup-repos/yay
    
    # Backup and remove existing dotfiles
    create_backup "$DOTFILES_DIR"
    rm -rf "$DOTFILES_DIR"
    
    # Clear symlinks
    for config in "${CONFIGS[@]}"; do
        find "$HOME/.config/$config" -type l -delete
    done
    
    # Clone dotfiles repository
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    handle_error $? "Failed to clone dotfiles repository"
    
    # Redo symlinks
    cd "$DOTFILES_DIR"
    for config in "${CONFIGS[@]}"; do
        stow -R "$config"
        handle_error $? "Failed to stow $config"
    done
    
    log_message "$COK Fix Setup completed."
}

# Main menu function
main_menu() {
    echo -e "\nPlease select a stage to run:"
    echo "1. All (Nvidia + Packages + Dotfiles)"
    echo "2. Nvidia Driver Install"
    echo "3. Package Installs"
    echo "4. Dotfiles Setup"
    echo "5. Fix Setup"
    echo "6. Exit"
    
    read -rp "Enter your choice [1-6]: " choice
    
    case $choice in
        1) nvidia_install && package_install && dotfiles_setup ;;
        2) nvidia_install ;;
        3) package_install ;;
        4) dotfiles_setup ;;
        5) fix_setup ;;
        6) exit 0 ;;
        *) echo -e "$CER Invalid choice. Please try again."; main_menu ;;
    esac
}

# Main execution
clear
log_message "$CNT Starting setup script..."
check_dependencies
source_config
main_menu
log_message "$COK Setup script completed successfully."