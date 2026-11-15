#!/bin/bash
# Night light toggle (SUPER+SHIFT+N), using hyprsunset.
# Schedule is in ~/.config/hypr/hyprsunset.conf; this just flips it by hand.

WARM=4000    # temperature when on (K)
NORMAL=6000  # temperature when off (K), hyprsunset's neutral default

# Make sure hyprsunset is running, otherwise hyprctl has nothing to talk to
if ! pgrep -x hyprsunset >/dev/null; then
    hyprsunset >/dev/null 2>&1 &
    sleep 0.5
fi

current=$(hyprctl hyprsunset temperature)

if [ "$current" -lt "$NORMAL" ]; then
    hyprctl hyprsunset temperature "$NORMAL" >/dev/null
    notify-send -a "Night light" -i weather-clear "Night light off"
else
    hyprctl hyprsunset temperature "$WARM" >/dev/null
    notify-send -a "Night light" -i weather-clear-night "Night light on"
fi
