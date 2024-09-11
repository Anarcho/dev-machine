#!/usr/bin/env bash

# Configuration
LOG_FILE="$HOME/.cache/waybar_start.log"
CONFIG_FILE="$HOME/.config/waybar/config.jsonc"
STYLE_FILE="$HOME/.config/waybar/style.css"

# Kill any existing Waybar instances
killall waybar

# Wait a moment to ensure all instances are terminated
sleep 0.5

# Function to start Waybar
start_waybar() {
    waybar -c "$CONFIG_FILE" -s "$STYLE_FILE" &
    echo "$(date): Waybar started" >> "$LOG_FILE"
}

# Function to send notification
send_notification() {
    if command -v notify-send &> /dev/null; then
        notify-send "Waybar" "Waybar has been restarted"
    fi
}

# Start Waybar initially
start_waybar

# Monitor Waybar and restart if it crashes
while true; do
    if ! pgrep -x "waybar" > /dev/null; then
        echo "$(date): Waybar crashed. Restarting..." >> "$LOG_FILE"
        start_waybar
        send_notification
    fi
    sleep 5
done