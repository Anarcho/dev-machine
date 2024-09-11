#!/usr/bin/env bash

json_field () {
    echo -n "\"$1\":\"$2\""
    [[ "$3" == "1" ]] && echo -n ","
}

time_24h="$(date '+%H:%M')"
time_12h="$(date '+%I:%M %p')"
time_date="$(date '+%A, %B %d, %Y')"

if [[ "$1" == "click-left" ]]; then
    notify-send -e "Uptime is..." "$(uptime -p | sed 's/up //')"
elif [[ "$1" == "click-right" ]]; then
    notify-send -e "The date is..." "$time_date"
fi

json_tooltip="$time_date"
json_text="$time_12h"

echo -n "{"
json_field 'text' "$json_text" 1
json_field 'tooltip' "$json_tooltip" 0
echo "}"
