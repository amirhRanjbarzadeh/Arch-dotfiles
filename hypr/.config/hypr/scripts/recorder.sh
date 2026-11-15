#!/bin/bash
# Screen recording toggle (SUPER+SHIFT+R).
# First press: pick a region and start. Second press: stop and save.

DIR="$HOME/Videos/Screencasts"

# Already recording? Ask it to stop (SIGINT = Ctrl+C, so the file is finished properly)
if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder
    exit 0
fi

mkdir -p "$DIR"
g=$(slurp) || exit 0                      # Esc in slurp = cancel
f="$DIR/$(date +%F_%H-%M-%S).mp4"

wf-recorder -g "$g" -f "$f" >/dev/null 2>&1
notify-send -a "Recorder" -i video-x-generic "Recording saved" "$f"
