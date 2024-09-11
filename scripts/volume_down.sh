#!/bin/bash
# Script to decrease volume by 5%

pactl set-sink-volume @DEFAULT_SINK@ -5%
