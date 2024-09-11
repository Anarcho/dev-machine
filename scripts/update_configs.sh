#!/bin/bash

# Log file for tracking updates
LOG_FILE=~/themes/update_configs.log
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect stdout and stderr to log file

echo "Updating configuration files with Tokyonight colors..." $(date)

# Paths
THEMES_DIR="$HOME/themes"
WAYBAR_CONFIG="$HOME/.config/waybar"
ROFI_CONFIG="$HOME/.config/rofi"
KITTY_CONFIG="$HOME/.config/kitty"

# Source the colors
source "$THEMES_DIR/colors.scss"

# Function to check last command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "$1 updated successfully."
    else
        echo "Error updating $1."
        exit 1
    fi
}

# Compile Waybar SCSS to CSS
echo "Updating Waybar configuration..."
sassc "$THEMES_DIR/waybar_style.scss" "$WAYBAR_CONFIG/style.css"
check_status "Waybar config"

# Generate Rofi theme
echo "Updating Rofi configuration..."
cat > "$ROFI_CONFIG/theme.rasi" << EOL
* {
    background:     ${black};
    background-alt: ${grey-900};
    foreground:     ${white};
    selected:       ${blue-dark};
    active:         ${green-dark};
    urgent:         ${red-dark};
}

window {
    background-color: @background;
    border:           1;
    padding:          5;
}

mainbox {
    border:  0;
    padding: 0;
}

message {
    border:       1px dash 0px 0px ;
    border-color: @separatorcolor;
    padding:      1px ;
}

textbox {
    text-color: @foreground;
}

listview {
    fixed-height: 0;
    border:       2px dash 0px 0px ;
    border-color: @separatorcolor;
    spacing:      2px ;
    scrollbar:    true;
    padding:      2px 0px 0px ;
}

element {
    border:  0;
    padding: 1px ;
}

element-text {
    background-color: inherit;
    text-color:       inherit;
}

element.normal.normal {
    background-color: @background;
    text-color:       @foreground;
}

element.normal.urgent {
    background-color: @urgent;
    text-color:       @foreground;
}

element.normal.active {
    background-color: @active;
    text-color:       @background;
}

element.selected.normal {
    background-color: @selected;
    text-color:       @background;
}

element.selected.urgent {
    background-color: @urgent;
    text-color:       @foreground;
}

element.selected.active {
    background-color: @selected;
    text-color:       @background;
}

element.alternate.normal {
    background-color: @background-alt;
    text-color:       @foreground;
}

element.alternate.urgent {
    background-color: @urgent;
    text-color:       @foreground;
}

element.alternate.active {
    background-color: @active;
    text-color:       @foreground;
}

scrollbar {
    width:        4px ;
    border:       0;
    handle-color: @selected;
    handle-width: 8px ;
    padding:      0;
}

mode-switcher {
    border:       2px dash 0px 0px ;
    border-color: @separatorcolor;
}

button {
    spacing:    0;
    text-color: @foreground;
}

button.selected {
    background-color: @selected;
    text-color:       @background;
}

inputbar {
    spacing:    0;
    text-color: @foreground;
    padding:    1px ;
}

case-indicator {
    spacing:    0;
    text-color: @foreground;
}

entry {
    spacing:    0;
    text-color: @foreground;
}

prompt {
    spacing:    0;
    text-color: @foreground;
}

inputbar {
    children:   [ prompt,textbox-prompt-colon,entry,case-indicator ];
}

textbox-prompt-colon {
    expand:     false;
    str:        ":";
    margin:     0px 0.3em 0em 0em ;
    text-color: @foreground;
}
EOL
check_status "Rofi config"

# Generate Kitty color config
echo "Updating Kitty configuration..."
cat > "$KITTY_CONFIG/kitty_colors.conf" << EOL
# Generated from colors.scss
foreground ${white}
background ${black}
cursor ${cursor}
cursor_text_color ${cursor-text}
selection_background ${selection-background}
selection_foreground ${selection-foreground}
color0 ${grey-900}
color1 ${red-dark}
color2 ${green-dark}
color3 ${yellow-dark}
color4 ${blue-dark}
color5 ${purple-dark}
color6 ${cyan-dark}
color7 ${white}
color8 ${grey-600}
color9 ${red-light}
color10 ${green-light}
color11 ${yellow-light}
color12 ${blue-light}
color13 ${purple-light}
color14 ${cyan-light}
color15 ${grey-050}
EOL
check_status "Kitty color config"

echo "All configs updated with Tokyonight color scheme."