#!/bin/sh
# Mirror the wallpaper picked in quickshell, and the colors derived from it, onto
# the SDDM login screen (the "island" theme from sddm/install.sh).
#
# The sddm user can't read your home directory, so install.sh gives the theme a
# user/ directory you own; this copies the wallpaper there and writes the colors
# to user/theme.conf.user (the theme's theme.conf.user links to it). No sudo needed.
# Does nothing when the theme isn't installed.
set -eu

dest=/usr/share/sddm/themes/island/user
state=${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper

[ -d "$dest" ] && [ -w "$dest" ] || exit 0
img=$(readlink -f "$state/current" 2>/dev/null) || exit 0
[ -f "$img" ] || exit 0

ext=${img##*.}
cp -f "$img" "$dest/.background.tmp"
rm -f "$dest"/background.*
mv -f "$dest/.background.tmp" "$dest/background.$ext"

# INI values without the leading "#": QSettings would read it as a comment.
{
    printf '[General]\nbackground=user/background.%s\n' "$ext"
    if [ -f "$state/theme.json" ]; then
        python3 -I -c '
import json, sys
colors = json.load(open(sys.argv[1])).get("colors", {})
for key, value in colors.items():
    print(key + "=" + value.lstrip("#"))
' "$state/theme.json"
    fi
} > "$dest/.theme.conf.user.tmp"
chmod 644 "$dest/background.$ext" "$dest/.theme.conf.user.tmp"
mv -f "$dest/.theme.conf.user.tmp" "$dest/theme.conf.user"
