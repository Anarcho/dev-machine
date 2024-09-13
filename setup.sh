#!/bin/bash

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"
CAC="[\e[1;33mACTION\e[0m]"
INSTLOG="install.log"

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
        yay -S --noconfirm $1 &>> $INSTLOG
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

    for SOFTWR in linux-headers nvidia-beta nvidia-utils-beta nvidia-settings-beta lib32-nvidia-utils-beta qt5-wayland qt5ct libva libva-nvidia-driver-git
    do
        install_software $SOFTWR
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
for SOFTWR in hyprland kitty # waybar jq mako swww swaylock-effects wofi wlogout xdg-desktop-portal-hyprland swappy grim slurp thunar
do
    install_software $SOFTWR 
done

# Stage 2 - more tools
# echo -e "$CNT - Stage 2 - Installing additional tools and utilities, this may take a while..."
# for SOFTWR in polkit-gnome python-requests pamixer pavucontrol brightnessctl bluez bluez-utils blueman network-manager-applet gvfs thunar-archive-plugin file-roller btop pacman-contrib
# do
#     install_software $SOFTWR
# done
# 
# echo -e "$CNT - Stage 3 - Installing theme and visual related tools and utilities, this may take a while..."
# for SOFTWR in starship ttf-jetbrains-mono-nerd noto-fonts-emoji lxappearance xfce4-settings sddm qt5-svg qt5-quickcontrols2 qt5-graphicaleffects
# do
#     install_software $SOFTWR
# done

# Start the bluetooth service
# echo -e "$CNT - Starting the Bluetooth Service..."
# sudo systemctl enable --now bluetooth.service &>> $INSTLOG
# sleep 2

# Enable the sddm login manager service
echo -e "$CNT - Enabling the SDDM Service..."
# sudo systemctl enable sddm &>> $INSTLOG
sleep 2

# Clean out other portals
# echo -e "$CNT - Cleaning out conflicting xdg portals..."
# yay -R --noconfirm xdg-desktop-portal-gnome xdg-desktop-portal-gtk &>> $INSTLOG

# New section for copying and linking configuration files
echo -e "$CNT - Setting up configuration files..."

# Hyprland
mkdir -p ~/.config/hypr
cp "$PWD/dotfiles/hypr/"* ~/.config/hypr/



ln -sf ~/.config/HyprV/kitty/kitty.conf ~/.config/kitty/kitty.conf
# ln -sf ~/.config/HyprV/mako/conf/config-dark ~/.config/mako/config
# ln -sf ~/.config/HyprV/swaylock/config ~/.config/swaylock/config
# ln -sf ~/.config/HyprV/waybar/conf/v3-config.jsonc ~/.config/waybar/config.jsonc
# ln -sf ~/.config/HyprV/waybar/style/v3-style-dark.css ~/.config/waybar/style.css
# ln -sf ~/.config/HyprV/wlogout/layout ~/.config/wlogout/layout
# ln -sf ~/.config/HyprV/wofi/config ~/.config/wofi/config
# ln -sf ~/.config/HyprV/wofi/style/v3-style-dark.css ~/.config/wofi/style.css

# Make the autostart script executable
chmod +x ~/.config/hypr/autostart.sh

# Check if the operations were successful
if [ $? -eq 0 ]; then
    echo -e "$COK - Configuration files have been set up successfully."
else
    echo -e "$CER - There was an error setting up the configuration files. Please check the paths and try again."
fi

### Script is done ###
echo -e "$CNT - Script had completed!"
if [[ "$ISNVIDIA" == true ]]; then 
    echo -e "$CAT - Since we attempted to setup Nvidia the script will now end and you should reboot.
    type 'reboot' at the prompt and hit Enter when ready."
    exit
fi

# read -rep $'[\e[1;33mACTION\e[0m] - Would you like to start Hyprland now? (y,n) ' HYP
# if [[ $HYP == "Y" || $HYP == "y" ]]; then
#     exec sudo systemctl start sddm &>> $INSTLOG
# else
#     exit
# fi