#!/bin/bash

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"
CAC="[\e[1;33mACTION\e[0m]"
INSTLOG="install.log"

# Set the location for your dotfiles
DOTFILES_DIR="$HOME/.dotfiles"

# URL of your dotfiles repository
DOTFILES_REPO="https://github.com/anarcho/dotfiles.git"

# clear the screen
clear

# Define ISNVIDIA variable early in the script
if lspci | grep -i nvidia &>/dev/null; then
    ISNVIDIA=true
    echo -e "$CNT - NVIDIA GPU detected."
else
    ISNVIDIA=false
    echo -e "$CNT - NVIDIA GPU not detected."
fi

# attempt to discover if this is a VM or not
echo -e "$CNT - Checking for Physical or VM..."
ISVM=$(hostnamectl | grep Chassis)
echo -e "Using $ISVM"
if [[ $ISVM == *"vm"* ]]; then
    echo -e "$CWR - Please note that VMs are not fully supported and if you try to run this on
    a Virtual Machine there is a high chance this will fail."
    sleep 1
fi

# let the user know that we will use sudo
echo -e "$CNT - This script will run some commands that require sudo. You will be prompted to enter your password.
If you are worried about entering your password then you may want to review the content of the script."
sleep 1

#### Check for package manager ####
ISYAY=/sbin/yay
if [ -f "$ISYAY" ]; then 
    echo -e "$COK - yay was located, moving on."
else 
    echo -e "$CWR - Yay was NOT located.. yay is (still) required"
    read -rep $'[\e[1;33mACTION\e[0m] - Would you like to install yay (y,n) ' INSTYAY
    if [[ $INSTYAY == "Y" || $INSTYAY == "y" ]]; then
        git clone https://aur.archlinux.org/yay.git &>> $INSTLOG
        cd yay
        makepkg -si --noconfirm &>> ../$INSTLOG
        cd ..
    else
        echo -e "$CER - Yay is (still) required for this script, now exiting"
        exit
    fi
    # update the yay database
    echo -e "$CNT - Updating the yay database..."
    yay -Suy --noconfirm &>> $INSTLOG
fi

install_software() {
    # First lets see if the package is there
    if yay -Q $1 &>> /dev/null ; then
        echo -e "$COK - $1 is already installed."
    else
        # no package found so installing
        echo -e "$CNT - Now installing $1 ..."
        yes | yay -S --noconfirm $1 &>> $INSTLOG
        # test to make sure package installed
        if yay -Q $1 &>> /dev/null ; then
            echo -e "\e[1A\e[K$COK - $1 was installed."
        else
            # if this is hit then a package is missing, exit to review log
            echo -e "\e[1A\e[K$CER - $1 install had failed, please check the install.log"
            exit
        fi
    fi
}

if [ "$ISNVIDIA" = true ]; then
    echo -e "$CNT - Nvidia setup stage, this may take a while..."

    # First, remove potentially conflicting NVIDIA packages
    echo -e "$CNT - Removing potentially conflicting NVIDIA packages..."
    yes | sudo pacman -Rdd nvidia nvidia-utils nvidia-settings 2>/dev/null
    yes | yay -Rdd nvidia nvidia-utils nvidia-settings 2>/dev/null

    # Install NVIDIA packages
    for SOFTWR in linux-headers nvidia-beta nvidia-utils-beta nvidia-settings-beta lib32-nvidia-utils-beta qt5-wayland qt5ct libva libva-nvidia-driver-git
    do
        echo -e "$CNT - Installing $SOFTWR..."
        yes | yay -S --noconfirm --answerdiff None --answerclean None --mflags "--noconfirm" $SOFTWR
        if [ $? -ne 0 ]; then
            echo -e "$CER - Failed to install $SOFTWR. Please check the logs and try again."
            exit 1
        fi
    done

    # Modify mkinitcpio.conf
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio --config /etc/mkinitcpio.conf --generate /boot/initramfs-custom.img
    echo -e "options nvidia-drm modeset=1" | sudo tee -a /etc/modprobe.d/nvidia.conf &>> $INSTLOG

    # Update GRUB to use the custom initramfs image
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg

    # Set up necessary environment variables
    echo -e "$CNT - Setting up environment variables for NVIDIA + Wayland..."
    sudo tee -a /etc/environment << EOF
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_RENDERER=vulkan
XCURSOR_SIZE=24
EOF

fi

# Stage 1 - main components
echo -e "$CNT - Stage 1 - Installing main components, this may take a while..."
for SOFTWR in hyprland kitty neovim # waybar jq mako swww swaylock-effects wofi wlogout xdg-desktop-portal-hyprland swappy grim slurp thunar
do
    install_software $SOFTWR 
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

# Config file setup
echo -e "$CNT - Setting up configuration files..."

# Hyprland
mkdir -p ~/.config/hypr
if ln -sf "$DOTFILES_DIR/hypr/"* ~/.config/hypr/; then
    echo -e "$COK - Hyprland configuration files symlinked successfully."
else
    echo -e "$CER - Failed to symlink Hyprland configuration files."
fi

# Kitty
mkdir -p ~/.config/kitty
if ln -sf "$DOTFILES_DIR/kitty/kitty.conf" ~/.config/kitty/kitty.conf; then
    echo -e "$COK - Kitty configuration file symlinked successfully."
else
    echo -e "$CER - Failed to symlink Kitty configuration file."
fi

# Neovim
mkdir -p ~/.config/nvim
if ln -sf "$DOTFILES_DIR/nvim/init.vim" ~/.config/nvim/init.vim; then
    echo -e "$COK - Neovim configuration file symlinked successfully."
else
    echo -e "$CER - Failed to symlink Neovim configuration file."
fi

# Make the autostart script executable
if [ -f ~/.config/hypr/autostart.sh ]; then
    chmod +x ~/.config/hypr/autostart.sh
    echo -e "$COK - Autostart script made executable."
else
    echo -e "$CWR - autostart.sh not found in ~/.config/hypr/"
fi

echo -e "$COK - Configuration files have been symlinked successfully."

### Script is done ###
echo -e "$CNT - Script had completed!"
if [[ "$ISNVIDIA" == true ]]; then 
    echo -e "$CAT - Since we attempted to setup Nvidia the script will now end and you should reboot.
    type 'reboot' at the prompt and hit Enter when ready."
    exit
fi