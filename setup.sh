#!/bin/bash

LOG_FILE=~/setup.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting enhanced Hyprland setup script..." $(date)

# Function to check last command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1 failed"
        exit 1
    fi
}

# Step 1: Update package database and upgrade system
echo "Updating package database and upgrading system..."
sudo pacman -Syu --noconfirm
check_status "System update"

# Step 2: Install yay (AUR helper)
if ! command -v yay &> /dev/null; then
    echo "Installing yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    check_status "Yay installation"
fi

# Step 3: Install packages
echo "Installing required packages..."
yay -S --needed --noconfirm hyprland-git wayland kitty sddm xdg-desktop-portal-hyprland xf86-video-nouveau mesa mkinitcpio wofi wlroots-git hyprutils-git hyprlang-git hyprcursor-git hyprwayland-scanner-git polkit-kde-agent xdg-desktop-portal-gtk pipewire wireplumber xdg-user-dirs
check_status "Package installation"

# Step 4: Enable SDDM
echo "Enabling SDDM service..."
sudo systemctl enable sddm.service
check_status "SDDM service enablement"

# Step 5: Modify mkinitcpio.conf for Nouveau
echo "Checking mkinitcpio.conf for nouveau..."
if ! grep -q "MODULES=(.*nouveau.*)" /etc/mkinitcpio.conf; then
    sudo sed -i '/^MODULES=/s/)/nouveau)/' /etc/mkinitcpio.conf
    check_status "Adding nouveau to mkinitcpio.conf"
else
    echo "Nouveau already present in mkinitcpio.conf"
fi

# Step 6: Rebuild initramfs
echo "Rebuilding initramfs..."
sudo mkinitcpio -P
check_status "Initramfs rebuild"

# Step 7: Set up user groups and services
echo "Setting up user groups and services..."
sudo usermod -aG video,input $(whoami)
sudo bash -c "echo i2c-dev | tee /etc/modules-load.d/i2c-dev.conf"
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service
check_status "User groups and services setup"

# Step 8: Set up environment variables
echo "Setting up environment variables..."
echo "export XDG_CURRENT_DESKTOP=Hyprland" >> ~/.bash_profile
echo "export XDG_SESSION_TYPE=wayland" >> ~/.bash_profile
echo "export XDG_SESSION_DESKTOP=Hyprland" >> ~/.bash_profile
echo "export QT_QPA_PLATFORM=wayland" >> ~/.bash_profile
echo "export GDK_BACKEND=wayland" >> ~/.bash_profile
check_status "Environment variables setup"

# Step 9: Create necessary directories
echo "Creating necessary directories..."
mkdir -p ~/.config/{hypr,kitty,wofi}
check_status "Directory creation"

# Step 10: Set up basic Hyprland configuration
echo "Setting up basic Hyprland configuration..."
cat << EOF > ~/.config/hypr/hyprland.conf
monitor=,preferred,auto,1

exec-once = waybar & hyprpaper & firefox

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
    sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
}

general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur = true
    blur_size = 3
    blur_passes = 1
    blur_new_optimizations = true
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_is_master = true
}

gestures {
    workspace_swipe = false
}

device:epic-mouse-v1 {
    sensitivity = -0.5
}

bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1

bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
EOF
check_status "Hyprland configuration setup"

echo "Setup completed successfully. Please reboot your system to start using your new Hyprland setup."
echo "After reboot, select Hyprland as your session at the login screen."