#!/bin/bash
INT=eDP-1
EXT=HDMI-A-1

if hyprctl monitors all -j | jq -e ".[] | select(.name==\"$EXT\") | .mirrorOf != \"none\"" >/dev/null; then
    hyprctl keyword monitor "$EXT, preferred, auto, 1"
else
    hyprctl keyword monitor "$EXT, 1920x1080@60Hz, auto, 1, mirror, $INT"
fi