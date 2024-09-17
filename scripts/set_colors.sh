#!/bin/bash

# Set some colors for logging
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"

# Define paths
DOTFILES_DIR="$HOME/.dotfiles"  # Adjust this path to your dotfiles directory
COLOR_FILE="$DOTFILES_DIR/templates/colors.txt"
WAYBAR_STYLE_FILE="$DOTFILES_DIR/config/waybar/style.css"  # Save the new file to your dotfiles directory

# Function to read colors from the central color file
read_colors() {
    if [ ! -f "$COLOR_FILE" ]; then
        echo -e "$CER - Color file not found at $COLOR_FILE"
        exit 1
    fi

    declare -A COLORS
    while IFS=': ' read -r key value; do
        COLORS[$key]=$value
    done < "$COLOR_FILE"
}

# Function to generate the Waybar style file based on color variables
generate_waybar_style() {
    echo -e "$CNT - Generating Waybar style file..."

    # Template for the style.css file with placeholders for colors
    cat > "$WAYBAR_STYLE_FILE" <<EOF
* {
    font-family: JetBrainsMono Nerd Font, FontAwesome, Roboto, Helvetica, Arial, sans-serif;
    font-size: 14px;
    font-weight: bold;
}

window#waybar {
    background-color: ${COLORS[background]};
    border-bottom: 8px solid ${COLORS[dark_gray]};
    color: ${COLORS[foreground]};
    transition-property: background-color;
    transition-duration: .5s;
}

window#waybar.hidden {
    opacity: 0.2;
}

#workspaces {
    margin: 0 4px;
}

#workspaces button {
    all: unset;
    background-color: ${COLORS[dark_gray]};
    color: ${COLORS[foreground]};
    border: none;
    border-bottom: 8px solid ${COLORS[gray]};
    border-radius: 5px;
    margin-left: 4px;
    margin-bottom: 2px;
    font-family: JetBrainsMono Nerd Font, sans-serif;
    font-weight: bold;
    font-size: 14px;
    padding-left: 15px;
    padding-right: 15px;
    transition: transform 0.1s ease-in-out;
}

#workspaces button:hover {
    background-color: ${COLORS[selection_bg]};
    border-bottom: 8px solid ${COLORS[blue]};
}

#workspaces button.active {
    background-color: ${COLORS[blue]};
    border-bottom: 8px solid ${COLORS[cyan]};
}

/* If workspaces is the leftmost module, omit left margin */
.modules-left > widget:first-child > #workspaces {
    margin-left: 0;
}

/* If workspaces is the rightmost module, omit right margin */
.modules-right > widget:last-child > #workspaces {
    margin-right: 0;
}

tooltip {
  background-color: ${COLORS[background]};
  border: none;
  border-bottom: 8px solid ${COLORS[dark_gray]};
  border-radius: 5px;
}

tooltip decoration {
  box-shadow: none;
}

tooltip decoration:backdrop {
  box-shadow: none;
}

tooltip label {
  color: ${COLORS[foreground]};
  font-family: JetBrainsMono Nerd Font, monospace;
  font-size: 16px;
  padding: 0 5px 5px;
}
EOF

    echo -e "$COK - Waybar style.css generated and saved to $WAYBAR_STYLE_FILE."
}

# Main function to set colors and generate files
set_colors() {
    read_colors
    generate_waybar_style
    # You can add more functions here for generating other configuration files if needed
}

# Run the main function
set_colors

# Optionally, move the generated style.css to your active Waybar configuration folder and restart Waybar
if [ -f "$WAYBAR_STYLE_FILE" ]; then
    echo -e "$CNT - Copying style.css to your active Waybar config folder..."
    cp "$WAYBAR_STYLE_FILE" "$HOME/.config/waybar/style.css"
    
    if command -v killall >/dev/null 2>&1; then
        echo -e "$CNT - Restarting Waybar..."
        killall waybar
        waybar &
        echo -e "$COK - Waybar restarted with the new style."
    else
        echo -e "$CWR - Unable to restart Waybar automatically. Please restart it manually to see changes."
    fi
else
    echo -e "$CER - Failed to generate style.css."
fi
