#!/bin/bash
# Script to increase volume by 5%

pactl set-sink-volume @DEFAULT_SINK@ +5%
