#!/bin/bash
choice=$(printf '%s\n' Lock Logout Suspend Reboot Shutdown | fuzzel --dmenu --prompt "power " --lines 5)

case "$choice" in
    Lock)     loginctl lock-session ;;
    Logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
