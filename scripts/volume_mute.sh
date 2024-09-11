#!/bin/bash
# Script to toggle mute

pactl set-sink-mute @DEFAULT_SINK@ toggle
