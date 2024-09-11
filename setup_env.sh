#!/bin/bash

LOG_FILE=~/setup.log
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect stdout and stderr to log file

echo "Starting setup script..." $(date)

# Function to check last command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1 failed"
        exit 1
    fi
}

# Step 1: Install packages
echo "Installing packages from packages.txt..."
if [ -f ./packages.txt ]; then
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm $(<packages.txt)
    check_status "Package installation"
else
    echo "Error: packages.txt not found!"
    exit 1
fi

# Step 2: Enable SDDM
echo "Enabling SDDM service..."
sudo systemctl enable sddm.service
check_status "SDDM service enablement"

# Step 3: Create necessary config directories
echo "Creating config directories..."
mkdir -p ~/.config/{hypr,waybar,rofi,kitty,wayland,xdg-desktop-portal,swaylock,mako} ~/.themes ~/themes/wallpapers
check_status "Config directory creation"

# Step 4: Copy configuration files
echo "Copying configuration files..."
cp ./configs/hypr/hyprland.conf ~/.config/hypr/
cp ./configs/hypr/hypridle.conf ~/.config/hypr/
cp ./configs/kitty/kitty.conf ~/.config/kitty/
cp ./configs/rofi/config.rasi ~/.config/rofi/
cp ./configs/waybar/waybar_config.json ~/.config/waybar/config.jsonc
cp ./configs/waybar/waybar_style.css ~/.config/waybar/style.css
mkdir -p ~/.config/waybar/scripts
cp ./configs/waybar/scripts/* ~/.config/waybar/scripts/
cp ./configs/xdg-desktop-portal/portals.conf ~/.config/xdg-desktop-portal/
cp ./configs/swaylock/config ~/.config/swaylock/
cp ./configs/mako/config ~/.config/mako/
cp -r ./configs/wayland/* ~/.config/wayland/
check_status "Configuration file copying"

# Step 5: Copy scripts
echo "Copying scripts..."
mkdir -p ~/.config/hypr/scripts
cp ./scripts/* ~/.config/hypr/scripts/
check_status "Script copying"

# Step 6: Copy themes
echo "Copying themes..."
cp ./themes/colors.scss ~/themes/
cp ./themes/kitty_colors.conf ~/.config/kitty/
cp ./themes/rofi_theme.scss ~/.config/rofi/
cp ./themes/waybar_style.scss ~/.config/waybar/
cp -r ./themes/wallpapers/* ~/themes/wallpapers/
check_status "Theme copying"

# Step 7: Setup Flatpak theming
echo "Setting up Flatpak theming..."
sudo flatpak override --filesystem=$HOME/.themes
sudo flatpak override --filesystem=$HOME/.icons
flatpak override --user --filesystem=xdg-config/gtk-4.0
check_status "Flatpak theme setup"

# Step 8: Modify mkinitcpio.conf for Nouveau
echo "Checking mkinitcpio.conf for nouveau..."
if ! grep -q "MODULES=(.*nouveau.*)" /etc/mkinitcpio.conf; then
    sudo sed -i '/^MODULES=/s/)/ nouveau)/' /etc/mkinitcpio.conf
    check_status "Adding nouveau to mkinitcpio.conf"
else
    echo "Nouveau already present in mkinitcpio.conf"
fi

# Step 9: Rebuild initramfs
echo "Rebuilding initramfs..."
sudo mkinitcpio -P
check_status "Initramfs rebuild"

# Step 10: Update configs with Tokyonight colors
echo "Updating configuration files with Tokyonight colors..."
chmod +x ~/.config/hypr/scripts/update_configs.sh
~/.config/hypr/scripts/update_configs.sh
check_status "Tokyonight color update"

# Step 11: Set up autostart
echo "Setting up autostart..."
cp ./autostart.sh ~/.config/hypr/
chmod +x ~/.config/hypr/autostart.sh
check_status "Autostart setup"

# Ensure all scripts are executable
chmod +x ~/.config/waybar/scripts/*.sh
chmod +x ~/.config/hypr/scripts/*.sh

echo "Setup completed successfully. Please reboot to start using your new setup with Hyprland."

# Additional instructions for the user
cat << EOL

After rebooting, your Hyprland environment will be ready. Here's what to expect:

1. Waybar: Will start automatically via the autostart script.
2. Wallpaper: Will be set automatically by the autostart script.
3. Idle and lock management: Hypridle and Swaylock are configured and will start automatically.
4. Notifications: Mako is configured and will start automatically.

Key shortcuts:
- Super + Space: Open Rofi application launcher
- Super + Return: Open Kitty terminal
- Check ~/.config/hypr/hyprland.conf for more keybindings

Additional steps you might want to take:
1. Customize your wallpaper: Edit ~/.config/hypr/scripts/set_wallpaper.sh
2. Adjust Waybar modules: Edit ~/.config/waybar/config.jsonc
3. Modify the color scheme: Edit ~/themes/colors.scss and run ~/.config/hypr/scripts/update_configs.sh

For any issues, check the log file at ~/setup.log

Enjoy your new Hyprland setup!
EOL